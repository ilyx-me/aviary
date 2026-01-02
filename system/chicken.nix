{ inputs, ... }: {

  imports = [
    inputs.hardware.nixosModules.common-cpu-intel
    inputs.hardware.nixosModules.common-pc-ssd
  ];

  config = {

    networking.hostName = "chicken";
    system.stateVersion = "25.11";

    nixpkgs.hostPlatform = "x86_64-linux";

    aviary.drive.primary = "/dev/disk/by-id/nvme-eui.0025385481b04ee1";

    boot.initrd.availableKernelModules = [
      "e1000e"
      "iwlmvm"
      "iwlwifi"
      "nvme"
      "sd_mod"
      "usb_storage"
      "xhci_pci"
    ];

    boot.kernelModules = [ "kvm-intel" ];

    # TODO REMOVE EVERYTHING BELOW ME

    systemd = {

      targets.multi-user.wants = [ "wpa_supplicant-recovery.service" ];

      services = {

        "wpa_supplicant-recovery" = {
          description = "WPA supplicant daemon (for interface wifi0)";
          requires = [ "sys-subsystem-net-devices-wifi0.device" ];
          after = [ "sys-subsystem-net-devices-wifi0.device" ];
          before = [ "network.target" ];
          wants = [ "network.target" ]; # TODO Does this make sense given before = [ "network.target" ] also?
          wantedBy = [ "multi-user.target" ];
          serviceConfig.Type = "simple";
          script = "/run/current-system/sw/bin/wpa_supplicant -c /persist/wpa_supplicant-wifi0.conf -i wifi0";
        };

        tailscaled.preStop = "/run/current-system/sw/bin/tailscale logout";
      };
    };
  };
}
