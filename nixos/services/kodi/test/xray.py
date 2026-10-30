# xray and image.tmdb.org for ./run.sh xray, what ../moviepipe/images.py
# asks: a connect proxy on 10808 (xray's mixed inbound) that takes DELAY s
# for every new tunnel, as barnard's xray did (15-50 s), to an
# image.tmdb.org of its own on 8443, tls with $STATE/xray/cert.pem (kodi
# trusts it, run.sh), its /t/p/ the mock's /img/. what it does to
# $STATE/xray.log
import os
import select
import socket
import socketserver
import ssl
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

STATE = os.environ.get("STATE", "/tmp/kodi-test")
DIR = os.path.join(STATE, "xray")
DELAY = float(sys.argv[1]) if len(sys.argv) > 1 else 8.0
HOST = "image.tmdb.org"
MOCK = "http://127.0.0.1:8765/img/"
os.makedirs(DIR, exist_ok=True)
LOG = open(os.path.join(STATE, "xray.log"), "a")
CERT, KEY = os.path.join(DIR, "cert.pem"), os.path.join(DIR, "key.pem")
# the mock straight, not through this container's proxy
OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))
tunnels = 0


def log(text):
    LOG.write(f"{time.strftime('%H:%M:%S')} {text}\n")
    LOG.flush()


if not os.path.exists(CERT):
    subprocess.run(
        ["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "365", "-keyout", KEY, "-out", CERT,
         "-subj", f"/CN={HOST}", "-addext", f"subjectAltName=DNS:{HOST}"],
        check=True, capture_output=True,
    )


class Origin(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *a):
        pass

    def do_GET(self):
        self.answer(True)

    def do_HEAD(self):
        self.answer(False)

    def answer(self, body):
        log(f"tmdb {self.command} {self.path}")
        code, data, kind = 404, b"", "text/plain"
        if self.path.startswith("/t/p/"):
            try:
                with OPENER.open(MOCK + self.path[len("/t/p/"):]) as r:
                    code, data, kind = 200, r.read(), r.headers["Content-Type"]
            except urllib.error.HTTPError as e:
                code = e.code
        self.send_response(code)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        if body:
            self.wfile.write(data)


class Proxy(socketserver.StreamRequestHandler):
    def handle(self):
        global tunnels
        line = self.rfile.readline().decode(errors="replace").split()
        while self.rfile.readline() not in (b"\r\n", b"\n", b""):
            pass
        if line[:2] != ["CONNECT", f"{HOST}:443"]:
            log(f"proxy refused {' '.join(line)}")
            self.wfile.write(b"HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\n\r\n")
            return
        tunnels += 1
        n = tunnels
        log(f"proxy tunnel {n}: {DELAY:g} s")
        time.sleep(DELAY)
        up = socket.create_connection(("127.0.0.1", 8443))
        self.wfile.write(b"HTTP/1.1 200 Connection established\r\n\r\n")
        self.wfile.flush()
        ends = [self.connection, up]
        try:
            while True:
                for end in select.select(ends, [], [])[0]:
                    data = end.recv(65536)
                    if not data:
                        return
                    (up if end is self.connection else self.connection).sendall(data)
        except OSError:
            pass
        finally:
            up.close()
            log(f"proxy tunnel {n} closed")


class Threads(socketserver.ThreadingMixIn, socketserver.TCPServer):
    daemon_threads = True
    allow_reuse_address = True


origin = ThreadingHTTPServer(("127.0.0.1", 8443), Origin)
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(CERT, KEY)
origin.socket = context.wrap_socket(origin.socket, server_side=True)
threading.Thread(target=origin.serve_forever, daemon=True).start()
proxy = Threads(("127.0.0.1", 10808), Proxy)
threading.Thread(target=proxy.serve_forever, daemon=True).start()
log(f"up, {DELAY:g} s a tunnel")
print("xray up", flush=True)
threading.Event().wait()
