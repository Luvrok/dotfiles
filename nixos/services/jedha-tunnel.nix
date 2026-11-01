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
      "/home/tunneluser/.ssh".d = {
        mode = "700";
        user = "tunneluser";
        group = "users";
      };
      "/home/tunneluser/.ssh/id_ed25519".f = {
        mode = "600";
        user = "tunneluser";
        group = "users";
      };
    };
  };

  fileSystems."/media/jedha-music" = {
    device = "root@192.168.0.217:/var/lib/media/music";
    fsType = "sshfs";
    options = [
      "_netdev"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "StrictHostKeyChecking=accept-new"
      "IdentityFile=/home/tunneluser/.ssh/id_ed25519"
      "allow_other"
      "reconnect"
      "ServerAliveInterval=15"
      "ServerAliveCountMax=3"
      # wait-online is off, an early access comes before wifi: ssh retries
      # once a second for a minute instead of failing the mount at once
      "ConnectionAttempts=60"
      "noauto"
    ];
  };

  fileSystems."/media/jedha-books" = {
    device = "root@192.168.0.217:/var/lib/media/books";
    fsType = "sshfs";
    options = [
      "_netdev"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "StrictHostKeyChecking=accept-new"
      "IdentityFile=/home/tunneluser/.ssh/id_ed25519"
      "allow_other"
      "reconnect"
      "ServerAliveInterval=15"
      "ServerAliveCountMax=3"
      # wait-online is off, an early access comes before wifi: ssh retries
      # once a second for a minute instead of failing the mount at once
      "ConnectionAttempts=60"
      "noauto"
    ];
  };

  fileSystems."/media/jedha-programming-books" = {
    device = "root@192.168.0.217:/var/lib/media/programming-books";
    fsType = "sshfs";
    options = [
      "_netdev"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "StrictHostKeyChecking=accept-new"
      "IdentityFile=/home/tunneluser/.ssh/id_ed25519"
      "allow_other"
      "reconnect"
      "ServerAliveInterval=15"
      "ServerAliveCountMax=3"
      # wait-online is off, an early access comes before wifi: ssh retries
      # once a second for a minute instead of failing the mount at once
      "ConnectionAttempts=60"
      "noauto"
    ];
  };

  systemd.services.jedha-tunnel = {
    description = "Persistent SSH tunnel to Jedha";
    wantedBy = [ "multi-user.target" ];

    # not needed at boot: wait for a route to jedha (wifi comes up late,
    # wait-online is off), quietly, instead of failing every 10 s
    path = [ pkgs.iproute2 ];
    preStart = ''
      until ip route get 192.168.0.217 >/dev/null 2>&1; do sleep 2; done
    '';

    serviceConfig = {
      User = "tunneluser";
      Type = "simple";
      TimeoutStartSec = "infinity";

      Restart = "on-failure";
      RestartSec = 10;

      ExecStart = ''
        ${pkgs.openssh}/bin/ssh \
          -i /home/tunneluser/.ssh/id_ed25519 \
          -p 22 jedha@192.168.0.217 \
          -L 18384:127.0.0.1:8384 \
          -L 8129:127.0.0.1:8129 \
          -L 8130:127.0.0.1:8130 \
          -L 4544:127.0.0.1:4544 \
          -L 4545:127.0.0.1:4545 \
          -L 4533:127.0.0.1:4533 \
          -L 4110:127.0.0.1:4110 \
          -L 5390:127.0.0.1:5390 \
          -N \
          -o ServerAliveInterval=30 \
          -o ServerAliveCountMax=3 \
          -o ExitOnForwardFailure=yes
      '';
    };
  };
}
