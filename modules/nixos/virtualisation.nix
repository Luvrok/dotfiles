{ pkgs, ... }:

{
  programs.virt-manager.enable = true;
  services.spice-vdagentd.enable = true;

  virtualisation = {
    virtualbox.host.enable = false;
    spiceUSBRedirection.enable = true;

    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        swtpm.enable = true;
        runAsRoot = true;
      };
    };
  };

  # Systemd service to autostart the default network
  systemd.services.libvirt-default-network = {
    description = "Autostart libvirt default network";
    after = [ "libvirtd.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
      ExecStart = "${pkgs.writeShellScript "libvirt-net-autostart" ''
        set -e
        export PATH="${pkgs.libvirt}/bin:${pkgs.coreutils}/bin:$PATH"
        virsh net-autostart default 2>/dev/null || virsh net-autostart default
        virsh net-start default 2>/dev/null || true
      ''}";
    };
  };

  environment.systemPackages = with pkgs; [
    qemu
    qemu-utils
    virt-manager
    virt-viewer
    virt-viewer
    spice
    spice-gtk
    spice-protocol
    spice-vdagent
    swtpm
  ];
}
