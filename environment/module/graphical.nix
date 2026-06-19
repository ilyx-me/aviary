{
   config,
   inputs,
   lib,
   pkgs,
   ...
}:

{
  config = {

    sops.secrets."sunshine-creds" = {
      mode = "0400";
      owner = config.users.users."1000".name;
      group = "users";
      path = "/home/1000/.config/sunshine/login.json";
    };

    boot = {
      consoleLogLevel = 3;
      kernelParams = [ "quiet" "systemd.show_status=auto" "rd.udev.log_level=3" "splash" ]; # plymouth.debug
      kernel.sysctl."vm.max_map_count" = 1048576;
      loader.timeout = lib.mkForce 0;
      initrd.verbose = false;

      plymouth = {
        enable = true;
        theme = "bgrt";
      };

      initrd.systemd.services.plymouth-start.serviceConfig.ExecStartPre = "/bin/sh -c 'while [ ! -e /dev/dri/by-path/pci-*-card ]; do :; done'";

      initrd.systemd.network.networks = {
        "99-ethernet-default-dhcp" = {
          matchConfig.Name = [ "en*" "eth*" ];

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
      useNetworkd = lib.mkForce false;
      wireless.enable = true;
      networkmanager.enable = true;
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
	nautilus
	nautilus-python
	papers
	resources
        steam-devices-udev-rules
      ];

      pathsToLink = [ "/share/nautilus-python/extensions" ];
      sessionVariables.NAUTILUS_4_EXTENSION_DIR = lib.mkForce "${pkgs.nautilus-python}/lib/nautilus/extensions-4";

      persistence."/persist".directories = [
        "/etc/NetworkManager/system-connections"
      ];
    };

    programs.steam.enable = true;

    # Required for Sunshine remote inputs
    hardware.uinput.enable = true;

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
	};
	applications = {
          env = {};
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

    users.users = {
      "999".extraGroups = [ "networkmanager" ];
      "1000".extraGroups = [ "networkmanager" "uinput" ];
    };

    # Prevent last second debug console messages after plymouth
    systemd.shutdownRamfs.enable = false;

    systemd.tmpfiles.rules = [
      "d /home/1000/.config 0700 ${config.users.users."1000".name} users -"
      "d /home/1000/.config/sunshine 0755 ${config.users.users."1000".name} users -"
    ];

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

          # Unhook
	  "myallychou@gmail.com" = {
	    install_url = "https://addons.mozilla.org/firefox/downloads/latest/youtube-recommended-videos/latest.xpi";
	    installation_mode = "normal_installed";
	  };

	  # Bitwarden
	  "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
	    install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
	    installation_mode = "normal_installed";
	  };

	  # Vimium
	  "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = {
	    install_url = "https://addons.mozilla.org/firefox/downloads/latest/vimium-ff/latest.xpi";
	    installation_mode = "normal_installed";
	  };

	  # No Tabs
	  "{c9f848fb-3fb6-4390-9fc1-e4dd4d1c5122}" = {
	    install_url = "https://addons.mozilla.org/firefox/downloads/latest/adsum-notabs/latest.xpi";
	    installation_mode = "normal_installed";
	  };

	  # Open external links in a container
	  "{f069aec0-43c5-4bbf-b6b4-df95c4326b98}" = {
	    install_url = "https://addons.mozilla.org/firefox/downloads/latest/open-url-in-container/latest.xpi";
	    installation_mode = "normal_installed";
	  };
        };
      };
    };

    home-manager.users."1000" = {

      xdg.desktopEntries = {
        "cups" = {
	  name = "cups";
	  noDisplay = true;
	};
        "nvim" = {
	  name = "nvim";
	  noDisplay = true;
	};
      };

      home.file.".librewolf/default/chrome/firefox-gnome-theme".source = inputs.firefox-gnome-theme;

      systemd.user.services = {
        "flathub" = {
          Unit = {
            After = [ "network-online.target" ];
            Description = "Add Flathub repo if not present";
          };
          Service = {
            Type = "oneshot";
            Restart = "on-failure";
            RestartSec = 30;
            ExecStart = "/run/current-system/sw/bin/flatpak -u remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo";
          };
          Install = {
            WantedBy = [ "default.target" ];
          };
        };

	"nixos-upgrade-notify" = {
          Install.WantedBy = [ "graphical-session.target" ];
          Service = {
            Type = "simple";
            ExecStart = pkgs.writeShellScript "nixos-upgrade-notify.sh" ''
	      status_last=""

              while read file; do
                  sleep 0.5

                  status_current=$(cat "$file" 2>/dev/null || echo -n "")

                  if [[ "$status_current" != "$status_last" ]]; then
		      case "$status_current" in
                          "nixos-upgrade-start")
		              /run/current-system/sw/bin/notify-send -a "NixOS System" \
		                  -u normal \
		                  -i "drive-harddisk" \
			          "Updating System" \
			          "Downloading and installing system updates. Performance may be impaired for the duration."
                              ;;
			  "nixos-upgrade-success")
                              /run/current-system/sw/bin/notify-send -a "NixOS System" \
		                  -u normal \
			          -i "drive-harddisk" \
			         "Update Successful" \
			         "In place upgrade complete. No action required."
			      ;;
			  "nixos-upgrade-reboot")
                              /run/current-system/sw/bin/notify-send -a "NixOS System" \
		                  -u critical \
			          -i "drive-harddisk" \
			         "Reboot Required" \
			         "Please restart the system to finalize remaining changes."
			      ;;
			  "nixos-upgrade-failure")
                              /run/current-system/sw/bin/notify-send -a "NixOS System" \
		                  -u critical \
			          -i "drive-harddisk" \
			          "Update Failed" \
			          "An error occured. Please run 'journalctl -u nixos-upgrade' for details."
			      ;;
		      esac

		      status_last="$status_current"
	          fi
	      done < <(/run/current-system/sw/bin/inotifywait -m -e modify --format '%w%f' /run/nixos-upgrade/status)
            '';
            Restart = "always";
          };
          Unit = {
            Description = "nixos-upgrade notifications";
            After = [ "graphical-session.target" ];
          };
        };
      };

      programs = {
        ghostty = {
	  enable = true;
	  package = null;
	  systemd.enable = false;
	  settings = {
            gtk-tabs-location = "hidden";
	    theme = "dark:Adwaita Dark,light:Adwaita";
	  };
        };

        librewolf = {
          enable = true;
	  package = null;

	  profiles."default".userChrome = ''
	    @import "firefox-gnome-theme/userChrome.css";

	    /* Hide tabs entirely */
	    #TabsToolbar {
	       visibility: collapse !important;
	    }
	  '';

	  profiles."default".userContent = ''
	    @import "firefox-gnome-theme/userContent.css";
	  '';

          settings = {
            "browser.download.useDownloadDir" = true;
            "browser.download.autohideButton" = false;
            "webgl.disabled" = false;
            "privacy.resistFingerprinting" = false; # Required for auto themeing
            #"privacy.clearOnShutdown.history" = false;
            #"privacy.clearOnShutdown.cookies" = false;
            "browser.toolbars.bookmarks.visibility" = "never";
            "browser.startup.page" = 3;
            #"extensions.pictureinpicture.enable_picture_in_picture_overrides" = true;
            #"browser.search.suggest.enabled" = true;
            "browser.uidensity" = 2;
            #"browser.urlbar.suggest.searches" = true;
	    "ui.key.menuAccessKey" = 0;

            # Config for no tabs
            "browser.uiCustomization.state" = ''{"placements":{"widget-overflow-fixed-list":[],"unified-extensions-area":["_d7742d87-e61d-4b78-b8a1-b469842139fa_-browser-action","ublock0_raymondhill_net-browser-action","myallychou_gmail_com-browser-action"],"nav-bar":["back-button","forward-button","stop-reload-button","urlbar-container","new-window-button","privatebrowsing-button","customizableui-special-spring8","vertical-spacer","_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action","unified-extensions-button","downloads-button"],"toolbar-menubar":["menubar-items"],"TabsToolbar":[],"vertical-tabs":["tabbrowser-tabs"],"PersonalToolbar":["personal-bookmarks"]},"seen":["developer-button","screenshot-button","ublock0_raymondhill_net-browser-action","_d7742d87-e61d-4b78-b8a1-b469842139fa_-browser-action","myallychou_gmail_com-browser-action","_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action"],"dirtyAreaCache":["unified-extensions-area","nav-bar","toolbar-menubar","TabsToolbar","vertical-tabs","PersonalToolbar","widget-overflow-fixed-list"],"currentVersion":23,"newElementCount":17}'';
	    "sidebar.verticalTabs.dragToPinPromo.dismissed" = true;
	    "browser.toolbarbuttons.introduced.sidebar-button" = true;
	    #"browser.link.open_newwindow" = 1; # Open links for 'new windows' in same tab
	    #"browser.link.open_newwindow.override.external" = 2; # Open links from external apps in a new window
	    "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
	    "svg.context-properties.content.enabled" = true;
	  };
        };
      };
    };
  };
}
