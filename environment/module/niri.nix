{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = {

    aviary.graphical = true;

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
    };

    programs.niri.enable = true;

    environment = {
      systemPackages = with pkgs; [
        ags
        walker
        xwayland-satellite
        swaybg

        adwaita-icon-theme
        baobab
        ghostty
        gnome-disk-utility
        mission-center
        nautilus
        nautilus-python

        flatpak-xdg-utils
        # kando # Need 2.0.0 for Niri
        #lisgd # For touchscreen gesture mapping
        # maliit-keyboard
        # squeekboard

        # Apparently requires patch
        # https://gist.github.com/itsCryne/6db136bec84047bff3a6fb694cf3f5ec
        # wvkbd
      ];

      pathsToLink = [ "/share/nautilus-python/extensions" ];
      sessionVariables.NAUTILUS_4_EXTENSION_DIR = lib.mkForce "${pkgs.nautilus-python}/lib/nautilus/extensions-4";
    };

    users.users."1000".extraGroups = [ "input" ];

    home-manager.users."1000" = {

      programs.bash.initExtra = ''
        if [[ $(tty) == "/dev/tty1" ]]; then
            unset PS1
        fi
      '';

      home.packages = [ pkgs.nerd-fonts.adwaita-mono ];

      dconf.settings = {
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
          monospace-font-name = "Adwaita Mono Font 10";
          gtk-theme = "Adwaita-dark";
        };
      };

      systemd.user.services.niri = {
        Unit = {
          Description = "A scrollable-tiling Wayland compositor";
          BindsTo = [ "graphical-session.target" ];
          Before = [ "graphical-session.target" "xdg-desktop-autostart.target" ];
          Wants = [ "graphical-session-pre.target" "xdg-desktop-autostart.target" ];
          After = [ "graphical-session-pre.target" ];
        };
        Service = {
          Slice = "session.slice";
          Type = "notify";
          Environment = "PATH=/run/current-system/sw/bin:/home/1000/.nix-profile/bin";
          ExecStart = "${pkgs.niri}/bin/niri --session";
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
  };
}
