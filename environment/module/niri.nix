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

  inherit (pkgs)
    writeShellScript
    ;

  greetdTemplate = lib.generators.toINI {} {
    initial_session = {
      command = "niri-session > /dev/null 2>&1";
    };
    default_session = {
      command = "${pkgs.greetd}/bin/agreety --cmd 'niri-session > /dev/null 2>&1'";
      user = "greeter";
    };
    terminal.vt = 1;
  };

  resolveGreetdUser = writeShellScript "resolve-greetd-user.sh" (
    readFile ../../script/systemd/resolveGreetdUser.sh
  );

  osk = writeShellScript "osk.sh" (
    readFile ../../script/systemd/osk.sh
  );

  lockScreen = writeShellScript "lock-screen.sh"(
    readFile ../../script/systemd/lockScreen.sh
  );

  lockScreenWait = writeShellScript "lock-screen-wait.sh" (
    readFile ../../script/systemd/lockScreenWait.sh
  );

in {

  imports = [
    inputs.noctalia.nixosModules.default
  ];

  config = {

    aviary.graphical = true;

    programs = {
      niri.enable = true;
      noctalia = {
        enable = true;
        systemd.enable = true;
      };
    };

    services = {
      accounts-daemon.enable = true;
      greetd.enable = true;
      gvfs.enable = true;
      iio-niri.enable = true;
      inputplumber.enable = true;
      upower.enable = true;
    };

    systemd = {

      tmpfiles.rules = [
        "d /etc/greetd 0755 root root - -"
        "f /etc/greetd/config.toml 0755 root root - ${ lib.strings.escapeC [ " " "\n" ] greetdTemplate }"
      ];

      services = {
        plymouth-quit = {
          after = [ "kanidm-unixd.service" ];
          before = [ "multi-user.target" ];
        };
        greetd = {
          serviceConfig = {
            ExecStartPre = "${resolveGreetdUser} ${config.aviary.primaryGid} ${pkgs.coreutils} ${pkgs.gnused}";
            ExecStart = lib.mkForce [ "${pkgs.greetd}/bin/greetd" ];
          };
        };
      };

      user = {
        services = {
          noctalia = {
            wantedBy = lib.mkForce [ "graphical-session-pre-lock.target" ];
            after = lib.mkForce [ "graphical-session-pre-lock.target" ];
            partOf = lib.mkForce [ "graphical-session-pre-lock.target" ];
            serviceConfig = {
              Type = "dbus";
              BusName = "org.freedesktop.Notifications";
              Environment = [
                "TZ=America/Los_Angeles"
                "_JAVA_AWT_WM_NONREPARENTING=1"
                "ELECTRON_OZONE_PLATFORM_HINT=auto"
                "QT_STYLE_OVERRIDE=adwaita"
                "QT_WAYLAND_DECORATION=adwaita"
              ];
              ExecStartPre = "${pkgs.niri}/bin/niri msg action do-screen-transition --delay-ms 2000";
            };
          };

          "osk" = {
            description = "On-Screen Keyboard";
            after = [ "graphical-session.target" ];
            wantedBy = [ "graphical-session.target" ];
            serviceConfig = {
              Type = "forking";
              ExecStart = "${osk} ${pkgs.niri} ${pkgs.gnugrep} ${pkgs.gawk} ${pkgs.wvkbd}";
              Restart = "always";
              RestartSec = 5;
            };
          };

          "noctalia-initial-lock" = {
            after = [ "noctalia.service" ];
            before = [
              "graphical-session.target"
              "xdg-desktop-autostart.target"
            ];
            bindsTo = [ "graphical-session.target" ];
            wantedBy = [ "noctalia.service" ];
            wants = [ "xdg-desktop-autostart.target" ];
            serviceConfig = {
              Type = "oneshot";
              TimeoutSec = "infinity";
              RemainAfterExit = "yes";
              ExecStart = "${lockScreenWait} ${pkgs.glib}";
            };
          };

          niri = {
            after = [ "graphical-session-pre.target" ];
            before = [ "graphical-session-pre-lock.target" ];
            bindsTo = [ "graphical-session-pre-lock.target" ];
            wants = [ "graphical-session-pre.target" ];
          };
        };

        targets = {

          graphical-session-pre = {
            overrideStrategy = "asDropin";
            before = [
              "graphical-session-pre-lock.target"
            ];
          };

          "graphical-session-pre-lock" = {
            description = "Initial user session lock for authentication";
            requires = [ "basic.target" ];
            before = [ "graphical-session.target" ];
            unitConfig = {
              RefuseManualStart = "yes";
              StopWhenUnneeded = "yes";
            };
          };
        };
      };
    };

    environment.systemPackages = with pkgs; [
      flatpak-xdg-utils
      glib
      kando
      lisgd # For touchscreen gesture mapping
      starship
      wvkbd
      xcursor-pro
      xwayland-satellite
    ];

    hjem.users.${config.aviary.primaryGid} = {
      files = {
        "Documents".type = "directory";
        "Downloads".type = "directory";
        "Pictures/Wallpapers/Dark/default.png".source = "${inputs.plasma-workspace-wallpapers}/Sub-Arctic/contents/images_dark/5120x2880.png";
        "Pictures/Wallpapers/Light/default.png".source = "${inputs.plasma-workspace-wallpapers}/Sub-Arctic/contents/images/5120x2880.png";
        "Templates".type = "directory";
        "Videos".type = "directory";
      };
      xdg = {
        config.files = {
          "fish/config.fish".text = ''
            if test "$TERM" != "dumb"; and test "$TERM" != "linux"
              starship init fish | source
            end
          '';
          "niri/aviaryUserOverrides.kdl" = {
            clobber = false;
            permissions = "0644";
            text = "";
            type = "copy";
          };
          "niri/config.kdl".source = ../../config/niri.kdl;
          "niri/noctalia.kdl" = {
            clobber = false;
            permissions = "0644";
            text = "";
            type = "copy";
          };
          "noctalia/settings.toml" = {
            generator = (pkgs.formats.toml {}).generate "noctalia.toml";
            value = {
              config_version = 12;
              backdrop.enabled = true;
              bar = {
                order = [ "main" ];
                main = {
                  background_opacity = 0.59999998658895493;
                  border_width = 0.5;
                  center = [ "clock" ];
                  concave_edge_corners = false;
                  end = [ "group:g3" "group:g1" "control-center" ];
                  margin_edge = 6;
                  position = "right";
                  radius = 16;
                  start = [ "osk" "group:g2" ];
                  thickness = 48;
                  widget_spacing = 12;
                  capsule_group = [
                    {
                      accordion = false;
                      accordion_direction = "start";
                      border = "";
                      enabled = true;
                      fill = "surface_variant";
                      id = "g1";
                      members = [ "bluetooth" "network" "volume" "battery" ];
                      opacity = 0.5;
                      padding = 16.0;
                    }
                    {
                      accordion = true;
                      accordion_direction = "end";
                      border = "";
                      enabled = true;
                      fill = "surface_variant";
                      id = "g2";
                      members = [ "workspaces" "tray" ];
                      opacity = 0.5;
                      padding = 16.0;
                    }
                    {
                      accordion = true;
                      accordion_direction = "start";
                      border = "";
                      enabled = true;
                      fill = "surface_variant";
                      id = "g3";
                      members = [ "notifications" "brightness" ];
                      opacity = 0.0;
                      padding = 6.0;
                    }
                  ];
                };
              };
              battery.warning_threshold = 20;
              brightness.minimum_brightness = 0.0099999997764825821;
              control_center = {
                sidebar = "none";
                sidebar_section = "none";
                width = 830;
              };
              dock = {
                background_opacity = 0.59999998658895493;
                border_width = 0.5;
                concave_edge_corners = false;
                cross_axis_padding = 0;
                enabled = true;
                icon_size = 35;
                item_spacing = 0;
                launcher_position = "start";
                magnification_scale = 1.2000000029802322;
                main_axis_padding = 4;
                margin_edge = 6;
                pinned = [
                  "librewolf"
                  "org.gnome.Nautilus"
                  "org.gnome.Papers"
                  "org.gnome.TextEditor"
                  "io.bassi.Amberol"
                  "org.gnome.Loupe"
                  "com.github.rafostar.Clapper"
                  "org.gnome.baobab"
                  "net.nokyan.Resources"
                  "com.mitchellh.ghostty"
                ];
                position = "left";
                show_dots = true;
                show_instance_count = false;
              };
              hooks = {
                started = "${lockScreen} ${config.programs.noctalia.package} ${pkgs.gnome-keyring}";
                theme_mode_changed = "${config.programs.noctalia.package}/share/noctalia/assets/templates/gtk/apply.sh --appearance-only $NOCTALIA_THEME_MODE";
              };
              hot_corners.enabled = true;
              idle = {
                behavior_order = [ "lock" "screen-off" "lock-and-suspend" ];
                behavior = {
                  lock = {
                    action = "lock";
                    enabled = true;
                    timeout = 360.0;
                  };
                  lock-and-suspend = {
                    action = "lock_and_suspend";
                    enabled = true;
                    timeout = 900.0;
                  };
                  screen-off = {
                    action = "screen_off";
                    enabled = true;
                    timeout = 300.0;
                  };
                };
              };
              location.auto_locate = true;
              lockscreen_widgets.enabled = false;
              notification = {
                background_opacity = 0.59999998658895493;
                border = false;
                history_retention_hours = 168;
                max_visible = 5;
                position = "top_center";
              };
              osd = {
                background_opacity = 0.59999998658895493;
                offset_x = 48;
                offset_y = 48;
                position = "bottom_center";
                position_vertical = "bottom_center";
              };
              shell = {
                avatar_path = "~/Pictures/Wallpapers/Light/default.png";
                clipboard_enabled = false;
                blipboard_history_max_entries = 10;
                corner_radius_scale = 2.0;
                polkit_agent = true;
                launcher.app_grid = true;
                panel = {
                  control_center_placement = "floating";
                  floating_offset = 6;
                  session_placement = "floating";
                  session_position = "center";
                  shadow = false;
                  wallpaper_placement = "floating";
                  wallpaper_position = "center";
                };
                session = {
                  grid = true;
                  grid_columns = 2;
                  show_shortcuts = false;
                  actions = [
                    {
                      action = "lock";
                      countdown_seconds = 0.0;
                      enabled = true;
                      variant = "default";
                    }
                    {
                      action = "lock_and_suspend";
                      countdown_seconds = 0.0;
                      enabled = true;
                      label = "Suspend";
                      variant = "default";
                    }
                    {
                      action = "reboot";
                      countdown_seconds = 0.0;
                      enabled = true;
                      variant = "default";
                    }
                    {
                      action = "shutdown";
                      countdown_seconds = 0.0;
                      enabled = true;
                      variant = "destructive";
                    }
                  ];
                };
              };
              theme = {
                builtin = "Noctalia";
                mode = "light";
                source = "wallpaper";
                wallpaper_scheme = "soft";
                templates.builtin_ids = [ "niri" "starship" ];
              };
              wallpaper = {
                directory_dark = "~/Pictures/Wallpapers/Dark";
                directory_light = "~/Pictures/Wallpapers/Light";
                transition = [ "fade" ];
                default.path = "/home/${config.aviary.primaryUuid}/Pictures/Wallpapers/Light/default.png";
                last.path = "/home/${config.aviary.primaryUuid}/Pictures/Wallpapers/Light/default.png";
              };
              widget = {
                battery = {
                  display_mode = "graphic";
                  scale = 0.5;
                  show_label = false;
                };
                brightness.show_label = false;
                clock = {
                  anchor = true;
                  capsule = false;
                };
                control-center.glyph = "power";
                launcher.glyph = "menu-2";
                network.show_label = false;
                osk = {
                  actions.left = "exec systemctl --user kill osk --signal=SIGRTMIN";
                  glyph = "keyboard";
                  tooltip = "Virtual Keyboard";
                  type = "custom_button";
                };
                tray.detached_panel = true;
                volume.show_label = false;
                workspaces.show_labels = false;
              };
            };
          };

          "starship.toml" = {
            clobber = true;
            generator = (pkgs.formats.toml {}).generate "starship.toml";
            permissions = "0644";
            type = "copy";
            value = {
              "$schema" = "https://starship.rs/config-schema.json";
              add_newline = false;

              format = lib.concatStrings [
                "[](fg:green)"
                "$nix_shell"
                "$username"
                "$os"
                "$hostname"
                "[](fg:green bg:cyan)"
                "$time"
                "[](fg:cyan bg:yellow)"
                "$cmd_duration"
                "[](fg:yellow)"
                "$status"
                "$line_break"
                "[](fg:green)"
                "$c"
                "$rust"
                "$golang"
                "$nodejs"
                "$php"
                "$java"
                "$kotlin"
                "$haskell"
                "$python"
                "$git_branch"
                "$git_status"
                "[](fg:green bg:cyan)"
                "$git_commit"
                "[](fg:cyan)"
                "$git_metrics"
                "$character"
              ];

              palette = "noctalia";

              os = {
                disabled = false;
                style = "fg:surface1 bg:green";
                symbols = {
                  Windows = "󰍲 ";
                  Ubuntu = "󰕈 ";
                  SUSE = " ";
                  Raspbian = "󰐿 ";
                  Mint = "󰣭 ";
                  Macos = "󰀵 ";
                  Manjaro = " ";
                  Linux = "󰌽 ";
                  Gentoo = "󰣨 ";
                  Fedora = "󰣛 ";
                  Alpine = " ";
                  Amazon = " ";
                  Android = " ";
                  Arch = "󰣇 ";
                  Artix = "󰣇 ";
                  CentOS = " ";
                  Debian = "󰣚 ";
                  Redhat = "󱄛 ";
                  RedHatEnterprise = "󱄛 ";
                  NixOS = " ";
                };
              };

              username = {
                style_user = "bold fg:surface1 bg:green";
                style_root = "bold fg:surface1 bg:green";
                format = "[$user]($style)";
              };

              hostname = {
                ssh_only = true;
                style = "bold fg:surface1 bg:green";
                format = "[$ssh_symbol$hostname]($style)";
              };

              nix_shell = {
                style = "bold fg:surface1 bg:green";
                impure_msg = "[● ](fg:red bg:green)";
                pure_msg = "[](fg:green bg:green)";
                format = "$state[$name]($style)";
              };

              git_commit = {
                only_detached = false;
                format = "[ $hash$tag]($style)";
                style = "bold fg:surface1 bg:cyan";
              };

              git_metrics = {
                disabled = false;
                format = "([ +$added]($added_Style) )([-$deleted](deleted_style))";
              };

              git_branch = {
                symbol = "";
                style = "bg:green";
                format = "[[$symbol[ $branch ](bold fg:surface1 bg:green)](fg:surface1 bg:green)]($style)";
              };

              git_status = {
                style = "bg:green";
                format = "[[($all_status$ahead_behind)](bold fg:surface1 bg:green)]($style)";
              };

              nodejs = {
                symbol = " ";
                style = "bg:green";
                format = "[[$symbol([ $version](bold fg:surface1 bg:green))](fg:surface1 bg:green)]($style)";
              };

              c = {
                symbol = " ";
                style = "bg:green";
                format = "[[$symbol([ $version](bold fg:surface1 bg:green))](fg:surface1 bg:green)]($style)";
              };

              rust = {
                symbol = " ";
                style = "bg:green";
                format = "[[$symbol([ $version](bold fg:surface1 bg:green))](fg:surface1 bg:green)]($style)";
              };

              golang = {
                symbol = " ";
                style = "bg:green";
                format = "[[$symbol([ $version](bold fg:surface1 bg:green))](fg:surface1 bg:green)]($style)";
              };

              php = {
                symbol = " ";
                style = "bg:green";
                format = "[[$symbol([ $version](bold fg:surface1 bg:green))](fg:surface1 bg:green)]($style)";
              };

              java = {
                symbol = " ";
                style = "bg:green";
                format = "[[$symbol([ $version](bold fg:surface1 bg:green))](fg:surface1 bg:green)]($style)";
              };

              kotlin = {
                symbol = " ";
                style = "bg:green";
                format = "[[$symbol([ $version](bold fg:surface1 bg:green))](fg:surface1 bg:green)]($style)";
              };

              haskell = {
                symbol = " ";
                style = "bg:green";
                format = "[[$symbol([ $version](bold fg:surface1 bg:green))](fg:surface1 bg:green)]($style)";
              };

              python = {
                symbol = " ";
                style = "bg:green";
                format = "[[$symbol([ $version](bold fg:surface1 bg:green))](fg:surface1 bg:green)]($style)";
              };

              time = {
                disabled = false;
                time_format = "%H:%M:%S";
                style = "bg:green";
                format = "[[ $time](bold fg:surface1 bg:cyan)]($style)";
              };

              line_break = {
                disabled = false;
              };

              character = {
                disabled = false;
                success_symbol = "[❯](bold fg:yellow)";
                error_symbol = "[❯](bold fg:red)";
                vimcmd_symbol = "[❮](bold fg:green)";
                vimcmd_replace_one_symbol = "[❮](bold fg:blue)";
                vimcmd_replace_symbol = "[❮](bold fg:blue)";
                vimcmd_visual_symbol = "[❮](bold fg:yellow)";
              };

              cmd_duration = {
                min_time = 0;
                show_milliseconds = true;
                style = "bg:yellow";
                format = "[ $duration]($style)";
              };

              status = {
                disabled = false;
                format = "[ $status]($style)";
              };
            };
          };
        };
        data.files = {
          "applications/dev.noctalia.Noctalia.desktop" = {
            generator = lib.generators.toINI {};
            value."Desktop Entry".NoDisplay = true;
          };
          "applications/kando.desktop" = {
            generator = lib.generators.toINI {};
            value."Desktop Entry".NoDisplay = true;
          };
        };
        state.files = {
          "noctalia/settings.toml" = {
            clobber = false;
            permissions = "0644";
            type = "copy";
            generator = (pkgs.formats.toml {}).generate "noctalia-state.toml";
            value = {
              config_version = 12;
            };
          };
        };
      };
    };
  };
}
