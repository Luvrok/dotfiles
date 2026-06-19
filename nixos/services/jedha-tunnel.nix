{ pkgs, ... }:

{
  users.users.tunneluser = {
    isNormalUser = true;
    description = "Tunnel user";
    home = "/home/tunneluser";
    createHome = true;
    shell = pkgs.bash;
  };

  systemd.tmpfiles.settings = {
    tunneluserSsh = {
      "home/tunneluser/.ssh".d = {
        mode = "700";
        user = "tunneluser";
        group = "tunneluser";
      };
      "home/tunneluser/.ssh/id_ed25519".f = {
        mode = "600";
        user = "tunneluser";
        group = "tunneluser";
      };
    };
  };

  systemd.services.jedha-tunnel = {
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
          -p 22 jedha@192.168.0.217 \
          -L 18384:127.0.0.1:8384 \
          -L 8129:127.0.0.1:8129 \
          -L 4544:127.0.0.1:4544 \
          -L 4545:127.0.0.1:4545 \
          -L 4533:127.0.0.1:4533 \
          -N \
          -o ServerAliveInterval=30 \
          -o ServerAliveCountMax=3 \
          -o ExitOnForwardFailure=yes
      '';
    };
  };
}
