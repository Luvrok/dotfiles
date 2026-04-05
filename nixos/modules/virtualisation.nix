{ pkgs, ... }:

{
  programs.virt-manager.enable = true;
  virtualisation.libvirtd.enable = true;
  virtualisation.virtualbox.host.enable = false;
  services.spice-vdagentd.enable = true;  

  environment.systemPackages = with pkgs; [
    qemu_kvm
    qemu-utils
    virt-viewer
    libvirt
    virt-manager
    spice-vdagent
  ];
}
