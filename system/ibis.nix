{
  inputs,
  pkgs,
  ...
}:

{
  imports = [
    inputs.hardware.nixosModules.microsoft-surface-pro-intel
    inputs.hardware.nixosModules.microsoft-surface-common
  ];

  config = {

    networking.hostName = "ibis";
    system.stateVersion = "25.11";

    nixpkgs.hostPlatform = "x86_64-linux";

    aviary = {
      drive.primary = "/dev/disk/by-id/nvme-eui.002538a311b7cacb";
      virtualDisplay = "HDMI-A-1";
    };

    hardware.microsoft-surface.kernelVersion = "stable";

    boot = {
      kernelModules = [ "kvm-intel" ];

      initrd = {
        kernelModules = [ "surface_aggregator_hub" ];
        availableKernelModules = [
          "8250_dw"
          "intel_lpss"
          "intel_lpss_pci"
          "iwlmvm"
          "iwlwifi"
          "nvme"
          "pinctrl_tigerlake"
          "surface_aggregator"
          "surface_aggregator_hub"
          "surface_aggregator_registry"
          "surface_hid"
          "surface_hid_core"
          "sd_mod"
          "thunderbolt"
          "usb_storage"
          "xhci_pci"
        ];
      };
    };

    hardware.bluetooth.enable = true;

    environment = {
      systemPackages = with pkgs; [
        iptsd
        libwacom-surface
      ];

      #Tablet file for libwacom-surface
      #From https://github.com/linux-surface/linux-surface/discussions/983
      #
      #Does not work because DeviceMatch=virt|045e|0c1b causes libwacom-surface crash, can't replicate on Debian
      etc."libwacom/microsoft-surface-laptop-studio.tablet".text = ''
        [Device]
        Name=Microsoft Corportation Surface Laptop Studio
        Class=PenDisplay
        DeviceMatch=virt:045e:0c1b
        PairedIDs=pci:045e:0c1b
        Width=11.94
        Height=7.96
        IntegratedIn=Display;System

        [Features]
        Stylus=true
        Touch=true
        Buttons=0
      '';

      #Enable touchpad in slate mode
      etc."libinput/local-overrides.quirks".text = ''
        [Microsoft Surface Laptop Studio Built-In Peripherals]
        MatchName=*Microsoft Surface*
        MatchDMIModalias=dmi:*svnMicrosoftCorporation:*pnSurfaceLaptopStudio:*
        ModelTabletModeNoSuspend=120

        [Microsoft Surface Laptop Studio Touchpad]
        MatchVendor=0x045E
        MatchProduct=0x09AF
        MatchUdevType=touchpad
        AttrPressureRange=25:10
        AttrPalmPressureThreshold=500
      '';
    };
  };
}
