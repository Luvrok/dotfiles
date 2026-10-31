# tmdb's posters and backdrops for kodi. image.tmdb.org (cloudfront)
# answers barnard's ip with 403 "blocked from your country", xray's mixed
# inbound (hosts/barnard/xray.nix) lets them through, but a new connection
# through it takes 15-50 s; a picture on one that's open, 0.1 s. kodi's
# curl opens new ones all the time and gives up on one after 20 s of
# nothing. so kodi asks this (../advancedsettings.xml's pathsubstitution:
# https://image.tmdb.org/t/p/ is http://127.0.0.1:PORT/t/p/ for kodi's
# files, tmdb helper's blur and the scraper's art included) and this asks
# image.tmdb.org through xray on a few connections it keeps open: an idle
# one asks a HEAD now and then, so neither cloudfront nor xray closes it.
# tmdb's api and the rest of kodi go straight. ./service.py runs it, no
# kodi in here
import http.client
import http.server
import queue
import select
import socketserver
import ssl
import threading
import time

HOST = "image.tmdb.org"
PROXY = ("127.0.0.1", 10808)
PORT = 8770
# connections kept open: kodi's textures load a few at a time
CONNECTIONS = 6
# s: a new connection through xray took up to 50, kodi waits 60
# (curllowspeedtime)
TIMEOUT = 90
# s: an idle connection's HEAD, and how often the idle ones are looked at
KEEP = 20
TICK = 5
# what goes back to kodi of tmdb's answer, besides the picture
HEADERS = ("Content-Type", "Cache-Control", "ETag", "Last-Modified")


class Connection:
    # one connection to image.tmdb.org through the proxy, opened when it's
    # first asked, again when the open one broke
    def __init__(self, pool):
        self.pool, self.http, self.used = pool, None, 0.0

    def open(self):
        self.close()
        conn = http.client.HTTPSConnection(*self.pool.proxy, timeout=TIMEOUT, context=self.pool.context)
        conn.set_tunnel(self.pool.host)
        conn.connect()
        self.http, self.used = conn, time.monotonic()

    def close(self):
        if self.http:
            self.http.close()
        self.http = None

    def dead(self):
        # closed by the other end while idle (xray restarted): its socket
        # reads. tls 1.3's session tickets read too, and are no picture
        sock = self.http and self.http.sock
        if not sock or not select.select([sock], [], [], 0)[0]:
            return False
        sock.setblocking(False)
        try:
            sock.recv(1)
            return True
        except ssl.SSLWantReadError:
            return False
        except OSError:
            return True
        finally:
            sock.settimeout(TIMEOUT)

    def ask(self, method, path):
        # (status, headers, body). one that was open may have been closed
        # since (xray restarted, cloudfront): once more on a new one
        for fresh in (False, True) if self.http else (True,):
            if fresh:
                self.open()
            try:
                self.http.request(method, path, headers={"Accept-Encoding": "identity"})
                r = self.http.getresponse()
                body = r.read()
            except (OSError, http.client.HTTPException):
                self.close()
                if fresh:
                    raise
                continue
            self.used = time.monotonic()
            if r.status == 200 and method == "GET":
                self.pool.last = path
            headers = [(k, r.getheader(k)) for k in HEADERS if r.getheader(k)]
            length = r.getheader("Content-Length") if method == "HEAD" else str(len(body))
            return r.status, headers + [("Content-Length", length or "0")], body


class Pool:
    # the connections, a request waits for a free one
    def __init__(self, proxy=PROXY, host=HOST, context=None, log=lambda message, bad: print(message)):
        self.proxy, self.host, self.context, self.log = proxy, host, context, log
        self.free = queue.LifoQueue()
        for _ in range(CONNECTIONS):
            self.free.put(Connection(self))
        # a picture tmdb has: what the HEAD asks
        self.last = "/t/p/w92/"
        self.failing = False

    def ask(self, method, path):
        conn = self.free.get(timeout=TIMEOUT)
        try:
            return conn.ask(method, path)
        finally:
            self.free.put(conn)

    def keep(self, conn):
        # an idle one: opened (at the start, after it broke) or its HEAD
        try:
            if conn.http:
                conn.ask("HEAD", self.last)
            else:
                conn.open()
            if self.failing:
                self.failing = False
                self.log(f"{self.host} through {self.proxy[0]}:{self.proxy[1]} again", False)
        except (OSError, http.client.HTTPException) as e:
            conn.close()
            if not self.failing:
                self.failing = True
                self.log(f"{self.host} through {self.proxy[0]}:{self.proxy[1]}: {e}", True)
        finally:
            self.free.put(conn)

    def tick(self):
        # the idle ones that need it, each in a thread of its own (opening
        # one takes long): not open, closed by the other end, idle KEEP s.
        # the rest back as they were, the last used on top
        idle = []
        while True:
            try:
                idle.append(self.free.get_nowait())
            except queue.Empty:
                break
        for conn in reversed(idle):
            if conn.dead():
                conn.close()
            if not conn.http or time.monotonic() - conn.used > KEEP:
                threading.Thread(target=self.keep, args=(conn,), daemon=True).start()
            else:
                self.free.put(conn)

    def close(self):
        while True:
            try:
                self.free.get_nowait().close()
            except queue.Empty:
                return


class Handler(http.server.BaseHTTPRequestHandler):
    # kodi's curl keeps its connection to this open too
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        self.forward("GET")

    def do_HEAD(self):
        self.forward("HEAD")

    def forward(self, method):
        try:
            status, headers, body = self.server.pool.ask(method, self.path)
        except (OSError, http.client.HTTPException, queue.Empty) as e:
            body = f"{HOST}: {e or 'busy'}\n".encode()
            status, headers = 502, [("Content-Type", "text/plain"), ("Content-Length", str(len(body)))]
        try:
            self.send_response(status)
            for k, v in headers:
                self.send_header(k, v)
            self.end_headers()
            if method == "GET":
                self.wfile.write(body)
        except OSError:
            # kodi gave up waiting
            self.close_connection = True

    def log_message(self, *args):
        pass


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


class Images:
    def __init__(self, port=PORT, **pool):
        self.port, self.pool = port, Pool(**pool)
        self.stopped = threading.Event()
        self.server = None

    def start(self):
        self.server = Server(("127.0.0.1", self.port), Handler)
        self.server.pool = self.pool
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        threading.Thread(target=self.keep, daemon=True).start()

    def keep(self):
        self.pool.tick()
        while not self.stopped.wait(TICK):
            self.pool.tick()

    def stop(self):
        self.stopped.set()
        if self.server:
            self.server.shutdown()
            self.server.server_close()
        self.pool.close()
