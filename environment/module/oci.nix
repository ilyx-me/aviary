{
  lib,
  ...
}:

{
  config = {

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
      ];

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
