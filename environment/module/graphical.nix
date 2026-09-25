{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let

  inherit (builtins)
    readFile
    ;

  inherit (lib)
    mkForce
    ;

  inherit (pkgs)
    writeShellScript
    ;

  addFlathubRemoteExecStart = writeShellScript "add-flathub-remote.sh" (
    readFile ../../script/systemd/addFlathubRemote.sh
  );

  nixosUpgradeNotifyExecStart = writeShellScript "nixos-upgrade-notify.sh" (
    readFile ../../script/systemd/nixosUpgradeNotify.sh
  );

in {
  options.aviary = {

    virtualDisplay = lib.mkOption {
      type = lib.types.str;
      default = null;
      example = "HDMI-A-2";
      description = "Display output to use for sunshine gpu accelerated virtual display";
    };
  };

  config = {

    sops.secrets."sunshine-creds" = {
      mode = "0400";
      #owner = 1984693245; #${config.aviary.primaryGid};
      #group = 1984693245; #${config.aviary.primaryGid};
      #path = "/home/${config.aviary.primaryUuid}/.config/sunshine/login.json";
    };

    boot = {
      consoleLogLevel = 3;
      kernelParams = [
        "quiet"
        "systemd.show_status=auto"
        "rd.udev.log_level=3"
        "splash"
        "video=${config.aviary.virtualDisplay}:e"
        "drm.edid_firmware=${config.aviary.virtualDisplay}:edid/virtual-display.bin"
        #"plymouth.debug"
      ];
      kernel.sysctl = {
        "vm.max_map_count" = 1048576;
        "net.core.netdev_budget" = 600;
        "net.core.netdev_budget_usecs" = 8000;
        "net.core.netdev_max_backlog" = 10000;
      };
      loader.timeout = mkForce 0;
      initrd.verbose = false;

      plymouth = {
        enable = true;
        theme = "bgrt";
      };

      initrd.systemd.services.plymouth-start.serviceConfig = {
        ExecStartPre = "/bin/sh -c 'while [ ! -e /dev/dri/by-path/pci-*-card ]; do :; done'";
        TimeoutStartSec = 10;
      };

      initrd.systemd.network.networks = {
        "99-ethernet-default-dhcp" = {
          matchConfig.Name = [
            "en*"
            "eth*"
          ];

          networkConfig = {
            DHCP = "yes";
            IPv6PrivacyExtensions = "kernel";
          };
        };

        "99-wireless-client-dhcp" = {
          matchConfig.WLANInterfaceType = "station";

          networkConfig = {
            DHCP = "yes";
            IPv6PrivacyExtensions = "kernel";
          };

          dhcpV4Config.RouteMetric = 1025;
          ipv6AcceptRAConfig.RouteMetric = 1025;
        };
      };
    };

    networking = {
      useNetworkd = mkForce false;
      wireless.enable = true;
      networkmanager = {
        enable = true;
        wifi.powersave = false;
      };
    };

    environment = {
      etc."firefox/policies/policies.json".target = "librewolf/policies/policies.json";
      systemPackages = with pkgs; [
        adwaita-icon-theme
        amberol
        baobab
        bazaar
        clapper
        clapper-enhancers
        flatpak
        gamescope
        ghostty
        gnome-disk-utility
        gnome-text-editor
        inotify-tools
        libnotify
        loupe
        mangohud
        moonlight-qt
        nautilus
        nautilus-python
        papers
        resources
        steam-devices-udev-rules
      ];

      pathsToLink = [ "/share/nautilus-python/extensions" ];
      sessionVariables.NAUTILUS_4_EXTENSION_DIR = mkForce "${pkgs.nautilus-python}/lib/nautilus/extensions-4";

      persistence."/persist".directories = [
        "/etc/NetworkManager/system-connections"
      ];
    };

    programs.steam.enable = true;

    hardware = {
      uinput.enable = true; # Required for Sunshine remote inputs
      display = {
        outputs."${config.aviary.virtualDisplay}".edid = "virtual-display.bin";
        edid.packages = [
          # from https://edid.build
          (pkgs.runCommand "edid-virtual-display" { } ''
            mkdir -p $out/lib/firmware/edid
            echo -n 'AP///////wAx2AAAAAAAAAEkAQOAAAB4Au6Ro1RMmSYPUFQAAAABAQEBAQEBAQEBAQEBAQEBGjaAoHA4H0AwIDUAAAAAAAAUAAAA/QAeeB//dwAKICAgICAgAAAA/ABWaXJ0dWFsIERpc3AKAAAAEAAAAAAAAAAAAAAAAAAAAeYCAymxRhAiP19hduIAymcDDAAAABhEathdxAF4gGAAHnjjBcAA4wYEARo2gKBwOB9AMCA1AAAAAAAAFJUuAKCgoBVQMCA1AAAAAAAAFG9eAKCgoClQMCA1AAAAAAAAFFbCAKCgoFVQMCA1AAAAAAAAFAAAAAAAAAAAAAAAAAAAKA==' | base64 -d > "$out/lib/firmware/edid/virtual-display.bin"
          '')
        ];
      };
    };

    services = {
      logind.settings.Login.WallMessages = "off";
      flatpak.enable = true;
      power-profiles-daemon.enable = true;
      printing.enable = true;
      pulseaudio.enable = false;
      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };
      sunshine = {
        enable = true;
        openFirewall = true;
        capSysAdmin = true;
        settings = {
          port = 47989;
          origin_web_ui_allowed = "pc";
          lan_encryption_mode = 2;
          wan_encryption_mode = 2;
          capture = "kms";
          credentials_file = "login.json";
          fec_percentage = 50;
        };
        applications = {
          env = { };
          apps = [
            {
              name = "Desktop";
              image-path = "desktop.png";
            }
            {
              name = "Desktop 2x";
              image-path = "desktop.png";
              prep-cmd = [
                {
                  do = "niri msg output eDP-1 scale 2.0";
                  undo = "niri msg output eDP-1 scale 1.5";
                }
              ];
            }
            {
              name = "Steam Big Picture";
              image-path = "steam.png";
              detached = [ "setsid steam steam://open/bigpicture" ];
              prep-cmd = [
                {
                  do = "";
                  undo = "setsid steam steam://close/bigpicture";
                }
              ];
            }
          ];
        };
      };
    };

    security.rtkit.enable = true;

    users.users."999".extraGroups = [ "networkmanager" ];

    # Prevent last second debug console messages after plymouth
    systemd.shutdownRamfs.enable = false;

    systemd.user.services = {
      "add-flathub-remote" = {
        description = "Add Flathub remote if not present";
        after = [ "network-online.target" ];
        wantedBy = [ "default.target" ];
        serviceConfig = {
          Type = "oneshot";
          Restart = "on-failure";
          RestartSec = 30;
          ExecStart = "${addFlathubRemoteExecStart} ${pkgs.flatpak}";
        };
      };
      "nixos-upgrade-notify" = {
        description = "nixos-upgrade notifications";
        after = [ "graphical-session.target" ];
        wantedBy = [ "graphical-session.target" ];
        serviceConfig = {
          Type = "simple";
          Restart = "always";
          ExecStart = "${nixosUpgradeNotifyExecStart} ${pkgs.libnotify} ${pkgs.inotify-tools}";
        };
      };
      sunshine = {
        after = mkForce [ "graphical-session-pre-lock.target" ];
        partOf = mkForce [ "graphical-session-pre-lock.target" ];
        wants = mkForce [ "graphical-session-pre-lock.target" ];
        wantedBy = mkForce [ "graphical-session-pre-lock.target" ];
      };
    };

    programs.firefox = {
      enable = true;
      package = pkgs.librewolf;
      policies = {
        DisableTelemetry = true;
        DisableFirefoxStudies = true;

        ExtensionSettings = {
          # Ublock
          "uBlock0@raymondhill.net" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
            installation_mode = "force_installed";
          };

          # Bitwarden
          "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
            installation_mode = "normal_installed";
          };
        };
      };
    };

    xdg.mime.defaultApplications = {
      "inode/directory" = "org.gnome.Nautilus.desktop";
      "text/plain" = "org.gnome.TextEditor.desktop";
      "audio/mpeg" = "io.bassi.Amberol.desktop";
      "audio/wav" = "io.bassi.Amberol.desktop";
      "audio/x-aac" = "io.bassi.Amberol.desktop";
      "audio/x-aiff" = "io.bassi.Amberol.desktop";
      "audio/x-ape" = "io.bassi.Amberol.desktop";
      "audio/x-flac" = "io.bassi.Amberol.desktop";
      "audio/x-m4a" = "io.bassi.Amberol.desktop";
      "audio/x-mp1" = "io.bassi.Amberol.desktop";
      "audio/x-mp2" = "io.bassi.Amberol.desktop";
      "audio/x-mp3" = "io.bassi.Amberol.desktop";
      "audio/x-mpeg" = "io.bassi.Amberol.desktop";
      "audio/x-mpegurl" = "io.bassi.Amberol.desktop";
      "audio/x-mpg" = "io.bassi.Amberol.desktop";
      "audio/x-pn-aiff" = "io.bassi.Amberol.desktop";
      "audio/x-pn-au" = "io.bassi.Amberol.desktop";
      "audio/x-pn-wav" = "io.bassi.Amberol.desktop";
      "audio/x-speex" = "io.bassi.Amberol.desktop";
      "audio/x-vorbis" = "io.bassi.Amberol.desktop";
      "audio/x-vorbis+ogg" = "io.bassi.Amberol.desktop";
      "audio/x-wavpack" = "io.bassi.Amberol.desktop";
      "x-scheme-handler/http" = "librewolf.desktop";
      "x-scheme-handler/https" = "librewolf.desktop";
    };

    hjem.users.${config.aviary.primaryGid} = {
      files = {
        ".local/share".type = "directory";
      };
      xdg = {
        config.files = {
          "ghostty/config.ghostty" = {
            generator = lib.generators.toKeyValue { mkKeyValue = lib.generators.mkKeyValueDefault {} " = "; };
            value = {
              gtk-tabs-location = "hidden";
              theme = "dark:Adwaita Dark,light:Adwaita";
            };
          };
          "librewolf/librewolf/default/chrome/firefox-gnome-theme".source = inputs.firefox-gnome-theme;
          "librewolf/librewolf/default/chrome/userChrome.css".text = ''@import "firefox-gnome-theme/userChrome.css'';
          "librewolf/librewolf/default/chrome/userContent.css".text = ''@import "firefox-gnome-theme/userContent.css'';
          "librewolf/librewolf/librewolf.overrides.cfg" = {
            clobber = false;
            source = ../../config/firefox/librewolf.overrides.cfg;
            type = "copy";
          };
          "librewolf/librewolf/profiles.ini" = {
            generator = lib.generators.toINI {};
            value = {
              Profile0 = {
                Name = "default";
                IsRelative = 1;
                Path = "default";
                Default = 1;
              };
              General = {
                StartWithLastProfile = 1;
                Version = 2;
              };
            };
          };
          "Moonlight Game Streaming Project/Moonlight.conf" = {
            generator = lib.generators.toINI {};
            value = {
              General = {
                audiocfg = 0;
                capturesyskeys = 1;
                connwarnings = false;
                gameopts = true;
                gamepadmouse = true;
                hostaudio = true;
                keepawake = true;
                quitAppAfter = true;
                uidisplaymode = 0;
                vsync = false;
                windowmode = 0;
              };
            };
          };
        };
        data.files = {
          "applications/btop.desktop" = {
            generator = lib.generators.toINI {};
            value."Desktop Entry".NoDisplay = true;
          };
          "applications/cups.desktop" = {
            generator = lib.generators.toINI {};
            value."Desktop Entry".NoDisplay = true;
          };
          "applications/dev.lizardbyte.app.Sunshine.desktop" = {
            generator = lib.generators.toINI {};
            value."Desktop Entry".NoDisplay = true;
          };
          "applications/nvim.desktop" = {
            generator = lib.generators.toINI {};
            value."Desktop Entry".NoDisplay = true;
          };
        };
      };
    };
  };
}
