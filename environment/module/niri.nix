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

    boot.kernelParams = [ "fbcon=nodefer" "vt.global_cursor_default=0" ];

    environment.persistence."/persist".directories = [ "/var/lib/AccountsService" ];

    programs.niri.enable = true;

    services.upower.enable = true;
    services.accounts-daemon.enable = true;
    services.iio-niri.enable = true;
    services.input-remapper = {
      enable = true;
      enableUdevRules = true;
    };

    services.greetd = {
      enable = true;
      settings.initial_session = {
        command = "niri-session > /dev/null 2>&1";
	user = config.users.users."1000".name;
      };
      settings.default_session = {
        command = "niri-session > /dev/null 2>&1"; # This session doesn't init correctly; need to look at user targets/services
	user = config.users.users."1000".name;
      };
    };

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

      tmpfiles.rules = [
        "C /var/lib/AccountsService/icons/${config.users.users."1000".name} - - - - ${builtins.path { path = "${inputs.secrets}/recovery/wallpaper.png"; }}"
      ];

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

    home-manager.users."1000" = {

      imports = [
        inputs.dms.homeModules.dank-material-shell
	inputs.dms-plugin-registry.modules.default
	inputs.danksearch.homeModules.default
      ];

      home.file = {
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

      programs.dsearch.enable = true;

      dconf.settings = {
        "org/gnome/desktop/interface" = {
          monospace-font-name = "Adwaita Mono Font 10";
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
        initExtra = "setterm -cursor on";
      };

      programs.dank-material-shell = {
        enable = true;
	enableSystemMonitoring = true;
	dgop.package = inputs.dgop.packages.${pkgs.stdenv.hostPlatform.system}.default;
	systemd.enable = true;
	plugins = {
	  dankActions.enable = true;
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
	    /home/1000/.nix-profile/bin/dms ipc profile setImage /var/lib/AccountsService/icons/${config.users.users."1000".name}
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

      systemd.user.services.osk = {
        Install.WantedBy = [ "graphical-session.target" ];
        Service = {
	  Type = "forking";
	  ExecStart = pkgs.writeShellScript "osk.sh" ''
	    resolution=$(/run/current-system/sw/bin/niri msg outputs | /run/current-system/sw/bin/grep "Logical size:" | /run/current-system/sw/bin/awk -F'[ ]' '{print $5}')
	    portrait=$(echo "$resolution" | /run/current-system/sw/bin/awk -F'[x]' '{print $1}')
	    landscape=$(echo "$resolution" | /run/current-system/sw/bin/awk -F'[x]' '{print $2}')
	    /run/current-system/sw/bin/wvkbd-mobintl -L $(( "$landscape"/3 )) -H $(( "$portrait"/3 )) --hidden &
	  '';
	  Restart = "always";
	  RestartSec = 5;
	};
	Unit = {
	  Description = "On-Screen Keyboard";
	  After = [ "graphical-session.target" ];
	};
      };
    };
  };
}
