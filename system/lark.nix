{
  inputs,
  lib,
  pkgs,
  ...
}:

{

  config = {

    networking.hostName = "lark";
    system.stateVersion = "26.05";

    nixpkgs.hostPlatform = "aarch64-linux";

    aviary.drive.primary = "/dev/disk/by-id/wwn-0x60e788a1e0b647f19b4562a634dd790d";

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
        "console=ttyAMA0"
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

    systemd.network.networks."05-enp1s0" = {
      address = [ "10.0.0.5/29" ];
      gateway = [ "10.0.0.1" ];
      linkConfig.MTUBytes = 9000;
      matchConfig.Name = "enp1s0";
      networkConfig.DHCP = "no";
      routes = [{
        Destination = "0.0.0.0/0";
        Gateway = "10.0.0.1";
        Table = "200";
      }];
      routingPolicyRules = [{
        Priority = 100;
        Table = "200";
        From = "10.0.0.5/32";
      }];
    };

    networking.nat = {
      enable = true;
      internalInterfaces = ["ve-+"];
      externalInterface = "enp1s0";
      enableIPv6 = true;
      forwardPorts = [
        {
          sourcePort = 25565;
          proto = "tcp";
          destination = "192.168.100.11:25565";
        }
        {
          sourcePort = 19132;
          proto = "udp";
          destination = "192.168.100.11:19132";
        }
      ];
    };

    environment.persistence."/persist".directories = [
      "/var/lib/nixos-containers"
    ];

    # Minecraft Server

    networking.firewall = {
      allowedTCPPorts = [ 25565 ];
      allowedUDPPorts = [ 19132 ];
    };

    containers.minecraft = {
      autoStart = true;
      privateNetwork = true;
      hostAddress = "192.168.100.10";
      localAddress = "192.168.100.11";
      hostAddress6 = "fc00::1";
      localAddress6 = "fc00::2";

      config = { ... }: {

        _module.args = { inherit inputs; };
        imports = [
          inputs.nix-minecraft.nixosModules.minecraft-servers
        ];

        system.stateVersion = "26.05";

        environment.enableAllTerminfo = true;

        networking = {
          firewall.allowedTCPPorts = [ 25565 ];
          firewall.allowedUDPPorts = [ 19132 ];

          # Use systemd-resolved inside the container
          # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
          useHostResolvConf = lib.mkForce false;
        };

        nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];

        services = {
          resolved.enable = true;

          minecraft-servers = {
            enable = true;
            eula = true;
            servers.papermc = {
              enable = true;
              package = pkgs.papermcServers.papermc-1_21_11;
              jvmOpts = "-Xms8G -Xmx8G -XX:+UseG1GC";
              serverProperties = {
                server-port = 25565;
                motd = "§eFully Healed! §fJK 😄";
                difficulty = 3;
                max-players = 10;
                white-list = true;
                online-mode = true;
                view-distance = 24;
                level-seed = "7565202949052331104";
              };
              whitelist = {
                user00 = "7653dfe3-f373-431a-941d-9cc4a0f192dc";
                user01 = "00000000-0000-0000-0009-01f5239d7633"; # Use https://cxkes.me/xbox/xuid hex for bedrock names
              };
              operators = {
                user00 = {
                  uuid = "7653dfe3-f373-431a-941d-9cc4a0f192dc";
                  level = 3;
                  bypassesPlayerLimit = true;
                };
              };
              symlinks = {
                "plugins/ViaVersion.jar" = pkgs.fetchurl {
                  url = "https://hangarcdn.papermc.io/plugins/ViaVersion/ViaVersion/versions/5.11.0/PAPER/ViaVersion-5.11.0.jar";
                  sha256 = "sha256-idt2yOPmdCOPXu4rt6npor7roHYLvRuGSUd46KWlL3A=";
                };
                "plugins/Geyser-Spigot.jar" = pkgs.fetchurl {
                  url = "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot";
                  sha256 = "sha256-GP4NtpeIWFz80GHkjdw9wagVywg72RLtdRMwNZ+L0V4=";
                };
                "plugins/Floodgate-Spigot.jar" = pkgs.fetchurl {
                  url = "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot";
                  sha256 = "sha256-RL25COL7T/G5dNUxPQSKYlohVVqYRM+4Ylapjo4ca9E=";
                };
              };
            };
          };
        };
      };
    };
  };
}
