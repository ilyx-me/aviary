{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

{
  config = {

    aviary.graphical = true;

    programs.niri.enable = true;

    systemd = {
      services."getty@tty1" = {
        overrideStrategy = "asDropin";
        serviceConfig = {
          ExecStart = [
	    ""
	    "/run/current-system/sw/bin/agetty --skip-login --nonewline --noissue --autologin ${config.users.users."1000".name} --noclear %I $TERM"
	  ];
        };
      };

      user.services.niri.enable = false;

      user.targets.graphical-session-pre = {
        overrideStrategy = "asDropin";
        before = [
	  "graphical-session-pre-lock.target"
	];
      };

      user.targets."graphical-session-pre-lock" = {
        description = "Initial user session lock for authentication";
	requires = [ "basic.target" ];
	before = [ "graphical-session.target" ];
	unitConfig = {
	  RefuseManualStart = "yes";
	  StopWhenUnneeded = "yes";
	};
      };
    };

    environment = {
      systemPackages = with pkgs; [
        xcursor-pro
	xwayland-satellite
	wvkbd

        flatpak-xdg-utils
        kando
        lisgd # For touchscreen gesture mapping
      ];
    };

    users.users."1000".extraGroups = [ "input" ];

    home-manager.users."1000" = {

      imports = [
        inputs.dms.homeModules.dank-material-shell
	inputs.dms-plugin-registry.modules.default
      ];

      home.file = {
        "profile.jpg" = {
	  source = "${inputs.secrets}/recovery/profile.jpg";
	  target = "/home/1000/.config/DankMaterialShell/profile.jpg";
	};
        "wallpaper.png" = {
	  source = "${inputs.secrets}/recovery/wallpaper.png";
	  target = "/home/1000/.config/DankMaterialShell/wallpaper.png";
	};
        "niri.kdl" = {
          source = ../../config/niri.kdl;
	  target = "/home/1000/.config/niri/config.kdl";
        };
      };

      systemd.user.tmpfiles.rules = [
        "f /home/1000/.config/niri/aviaryUserOverrides.kdl 0644 ${config.users.users."1000".name} users - -"
	"C /home/1000/.config/DankMaterialShell/clsettings.json - - - - ${builtins.path { path = ../../config/dms/clsettings.json; }}"
	"z /home/1000/.config/DankMaterialShell/clsettings.json 0644 ${config.users.users."1000".name} users - -"
	"C /home/1000/.config/DankMaterialShell/plugin_settings.json - - - - ${builtins.path { path = ../../config/dms/plugin_settings.json; }}"
        "z /home/1000/.config/DankMaterialShell/plugin_settings.json 0644 ${config.users.users."1000".name} users - -"
        "C /home/1000/.config/DankMaterialShell/settings.json - - - - ${builtins.path { path = ../../config/dms/settings.json; }}"
        "z /home/1000/.config/DankMaterialShell/settings.json 0644 ${config.users.users."1000".name} users - -"
        "C /home/1000/.local/state/DankMaterialShell/session.json - - - - ${builtins.path { path = ../../config/dms/session.json; }}"
        "z /home/1000/.local/state/DankMaterialShell/session.json 0644 ${config.users.users."1000".name} users - -"
      ];

      home.packages = [ pkgs.nerd-fonts.adwaita-mono ];

      dconf.settings = {
        "org/gnome/desktop/interface" = {
          # color-scheme = "prefer-dark";
          monospace-font-name = "Adwaita Mono Font 10";
          # gtk-theme = "Adwaita-dark";
        };
      };

      # Used by DMS but we don't want the app to show up in the launcher
      xdg.desktopEntries.khal = {
        name = "ikhal";
	exec = "ikhal";
        noDisplay = true;
      };

      programs.bash = {
        enable = true;
        initExtra = ''
          if [[ $(tty) == "/dev/tty1" ]]; then
	      unset PS1
              niri-session > /dev/null 2>&1
	  fi
        '';
      };

      programs.dank-material-shell = {
        enable = true;
	enableSystemMonitoring = true;
	dgop.package = inputs.dgop.packages.${pkgs.system}.default;
	systemd.enable = true;
	plugins = {
	  dankActions.enable = true;
	  dankKDEConnect.enable = true;
	};
      };

      systemd.user.services.dms = {
        Install.WantedBy = lib.mkForce [ "graphical-session-pre-lock.target" ];
	Unit = {
	  After = lib.mkForce [ "graphical-session-pre-lock.target" ];
	  PartOf = lib.mkForce [ "graphical-session-pre-lock.target" ];
	};
        Service = {
          Type = "dbus";
	  BusName = "org.freedesktop.Notifications";
	  ExecStartPre = "/run/current-system/sw/bin/niri msg action do-screen-transition --delay-ms 5000";
	};
      };

      systemd.user.services."dms-initial-lock" = {
        Install.WantedBy = [ "dms.service" ];
	Unit = {
	  After = [ "dms.service" ];
	  BindsTo = [ "graphical-session.target" ];
	  Before = [ "graphical-session.target" "xdg-desktop-autostart.target" ];
	  Wants = [ "xdg-desktop-autostart.target" ];
	};
	Service = {
	  Type = "oneshot";
	  RemainAfterExit = "yes";
	  ExecStart = pkgs.writeShellScript "dms-initial-lock" ''
	    /run/current-system/sw/bin/loginctl lock-session
	    /run/current-system/sw/bin/gnome-keyring-daemon --replace
	    while IFS= read -r line; do
		if [[ "$line" =~ "org.freedesktop.login1.Session.Unlock" ]]; then
		    break
		fi
	    done < <(/home/1000/.nix-profile/bin/gdbus monitor -y -d org.freedesktop.login1)
	  '';
	};
      };

      systemd.user.services.niri = {
        Service = {
	  Slice = "session.slice";
	  Type = "notify";
	  ExecStart = "/run/current-system/sw/bin/niri --session";
	};
	Unit = {
	  Description = "A scrollale-tiling Wayland compositor";
	  BindsTo = [ "graphical-session-pre-lock.target" ];
	  Before = [ "graphical-session-pre-lock.target" ];
	  Wants = [ "graphical-session-pre.target" ];
	  After = [ "graphical-session-pre.target" ];
	};
      };
    };
  };
}
