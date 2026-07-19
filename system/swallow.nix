{
  lib,
  ...
}:

{

  config = {

    networking.hostName = "swallow";
    system.stateVersion = "26.05";

    nixpkgs.hostPlatform = "x86_64-linux";

    aviary.drive.primary = "/dev/disk/by-id/wwn-0x600059fd17194a4f9b6c583e1f65a864";

    boot = {
      loader.systemd-boot = {
        enable = true;
        editor = false;
      };

      kernelParams = [
        "nvme.shutdown_timeout=10"
        "nvme_core.shutdown_timeout=10"
        "libiscsi.debug_libiscsi_eh=1"
        "crash_kexec_post_notifiers"
        "console=ttyS0"
      ];

      kernelModules = [ "kvm-amd" ];
      initrd.availableKernelModules = [
        "usbhid"
        "virtio_net"
        "virtio_pci"
        "virtio_scsi"
        "xhci_pci"
      ];
    };

    services = {
      cloud-init.enable = true;
      fwupd.enable = lib.mkForce false;
    };

    users.users."999".hashedPasswordFile = lib.mkForce null;
    users.users."1000".hashedPasswordFile = lib.mkForce null;
  };
}
