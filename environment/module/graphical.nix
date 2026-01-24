{
   lib,
   pkgs,
   ...
}:

{
  config = {
    boot = {
      consoleLogLevel = 3;
      kernelParams = [ "quiet" "udev.log_level=3" "systemd.show_status=auto" ];
      loader.timeout = lib.mkForce 0;
      initrd.verbose = false;

      plymouth = {
        enable = true;
        theme = "loader_2";
	themePackages = [
	  (pkgs.adi1090x-plymouth-themes.override {
	    selected_themes = [ "loader_2" ];
	  })
	];
      };

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
      wireless.enable = lib.mkForce false;
      networkmanager.enable = true;
    };

    environment = {
      systemPackages = with pkgs; [
        flatpak
        gnome-software
        steam-devices-udev-rules
      ];

      persistence."/persist".directories = [
        "/etc/NetworkManager/system-connections"
      ];
    };

    services = {
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
    };

    security.rtkit.enable = true;

    users.users = {
      "999".extraGroups = [ "networkmanager" ];
      "1000".extraGroups = [ "networkmanager" ];
    };

    home-manager.users."1000" = {

      systemd.user.services."flathub" = {
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

      programs = {
        ghostty.settings = {
          gtk-tabs-location = "hidden";
        };

        librewolf = {
          enable = true;
          settings = {
            "browser.download.alwaysOpenPanel" = true;
            "browser.download.autohideButton" = true;
            "webgl.disabled" = false;
            "privacy.resistFingerprinting" = false;
            "privacy.clearOnShutdown.history" = false;
            "privacy.clearOnShutdown.cookies" = false;
            "network.cookie.lifetimePolicy" = 0;
            "browser.toolbars.bookmarks.visibility" = "never";
            "browser.startup.page" = 3;
            "extensions.pictureinpicture.enable_picture_in_picture_overrides" = true;
            "browser.newtabpage.activity-stream.showSearch" = false;
            "browser.search.separatePrivateDefault" = false;
            "browser.search.suggest.enabled.private" = true;
            "browser.search.suggest.enabled" = true;
            "browser.uidensity" = 2;
            "browser.urlbar.suggest.searches" = true;
            "general.useragent.compatMode.firefox" = true;
            "sidebar.verticalTabs" = true;
            "sidebar.main.tools" = "history,bookmarks";
            "browser.uiCustomization.navBarWhenVerticalTabs" = ''["vertical-spacer","back-button","forward-button","stop-reload-button","urlbar-container","downloads-button","fxa-toolbar-menu-button","ublock0_raymondhill_net-browser-action","unified-extensions-button"]'';
            #"browser.uiCustomization.state" = ''{"placements":{"widget-overflow-fixed-list":[],"unified-extensions-area":[],"nav-bar":["sidebar-button","vertical-spacer","back-button","forward-button","stop-reload-button","urlbar-container","downloads-button","fxa-toolbar-menu-button","ublock0_raymondhill_net-browser-action","unified-extensions-button"],"toolbar-menubar":["menubar-items"],"TabsToolbar":[],"vertical-tabs":["tabbrowser-tabs"],"PersonalToolbar":["personal-bookmarks"]},"seen":["ublock0_raymondhill_net-browser-action","developer-button","screenshot-button"],"dirtyAreaCache":["unified-extensions-area","nav-bar","toolbar-menubar","TabsToolbar","PersonalToolbar","vertical-tabs"],"currentVersion":23,"newElementCount":21}'';
          };
        };
      };
    };
  };
}
