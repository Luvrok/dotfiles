{ pkgs, ... }:

{
  users.users.tunneluser = {
    isNormalUser = true;
    description = "Tunnel user";
    home = "/home/tunneluser";
    createHome = true;
    shell = pkgs.bash;
  };

  systemd.services.tatooine-tunnel = {
    description = "Persistent SSH tunnel to Tatooine";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      User = "tunneluser";
      Restart = "on-failure";
      RestartSec = 10;

      ExecStart = ''
        ${pkgs.openssh}/bin/ssh -i /home/tunneluser/.ssh/id_ed25519 \
          -p 22 tatooine@45.38.20.238 \
          -L 18384:127.0.0.1:8384 -N \
          -o ServerAliveInterval=30 -o ServerAliveCountMax=3
      '';
    };
  };
}
