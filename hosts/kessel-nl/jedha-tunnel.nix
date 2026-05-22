{ pkgs, ... }:

{
  users.users.tunneluser = {
    isNormalUser = true;
    description = "Tunnel user";
    home = "/home/tunneluser";
    createHome = true;
    shell = pkgs.bash;
  };

  systemd.tmpfiles.rules = [
    "d /home/tunneluser/.ssh 700 tunneluser tunneluser -"
    "f /home/tunneluser/.ssh/id_ed25519 600 tunneluser tunneluser -"
  ];

  environment.systemPackages = [ pkgs.socat ];

  systemd.services.kessel-tunnel = {
    description = "Persistent SSH tunnel to Jedha";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      User = "tunneluser";
      Type = "simple";

      Restart = "on-failure";
      RestartSec = 10;

      ExecStart = ''
        ${pkgs.openssh}/bin/ssh \
          -i /home/tunneluser/.ssh/id_ed25519 \
          -p 22 jedha@202:8b91:d873:c310:dd1d:5f1d:b20f:2a62 \
          -L 0.0.0.0:14544:127.0.0.1:4544 \
          -L 0.0.0.0:14533:127.0.0.1:4533 \
          -L 0.0.0.0:18129:127.0.0.1:8129 \
          -L 0.0.0.0:18208:127.0.0.1:8208 \
          -N \
          -o ServerAliveInterval=30 \
          -o ServerAliveCountMax=3 \
          -o ExitOnForwardFailure=yes
      '';
    };
  };
}
