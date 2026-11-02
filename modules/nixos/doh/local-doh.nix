{ pkgs, ... }:

let
  cert = pkgs.runCommand "dnscrypt-local-doh-cert" { nativeBuildInputs = [ pkgs.openssl ]; } ''
    mkdir -p $out

    openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
      -keyout ca.key -out $out/ca.crt -days 3650 \
      -subj "/CN=dnscrypt-proxy local DoH CA" \
      -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
      -addext "keyUsage=critical,keyCertSign,cRLSign" \
      -addext "nameConstraints=critical,permitted;IP:127.0.0.1/255.255.255.255"

    openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
      -keyout $out/server.key -out server.csr -subj "/CN=127.0.0.1"

    cat > ext.cnf <<EOF
    basicConstraints=critical,CA:FALSE
    keyUsage=critical,digitalSignature
    extendedKeyUsage=serverAuth
    subjectAltName=IP:127.0.0.1
    EOF

    openssl x509 -req -in server.csr -CA $out/ca.crt -CAkey ca.key \
      -set_serial 0x$(openssl rand -hex 16) -days 3650 -sha256 \
      -extfile ext.cnf -out $out/server.crt

    openssl verify -CAfile $out/ca.crt -purpose sslserver $out/server.crt
  '';
in
{
  services.dnscrypt-proxy.settings.local_doh = {
    listen_addresses = [ "127.0.0.1:3053" ];
    path = "/dns-query";
    cert_file = "${cert}/server.crt";
    cert_key_file = "${cert}/server.key";
  };

  environment.etc."dnscrypt-proxy/local-doh-ca.crt".source = "${cert}/ca.crt";
}
