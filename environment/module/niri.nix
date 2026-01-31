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

    programs.dank-material-shell.greeter = {
      enable = true;
      compositor.name = "niri";
      configHome = "/home/1000";

      logs = {
        save = true;
	path = "/tmp/dms-greeter.log";
      };
    };

    environment = {
      systemPackages = with pkgs; [
        xwayland-satellite

        flatpak-xdg-utils
        # kando # Need 2.0.0 for Niri
        # lisgd # For touchscreen gesture mapping
        # maliit-keyboard
        # squeekboard

        # Apparently requires patch
        # https://gist.github.com/itsCryne/6db136bec84047bff3a6fb694cf3f5ec
        # wvkbd
      ];
    };

    users.users."1000".extraGroups = [ "input" ];

    home-manager.users."1000" = {

      imports = [
        inputs.niri.homeModules.niri
        inputs.dms.homeModules.dank-material-shell
	inputs.dms.homeModules.niri
      ];

      home.packages = [ pkgs.nerd-fonts.adwaita-mono ];

      dconf.settings = {
        "org/gnome/desktop/interface" = {
          color-scheme = "prefer-dark";
          monospace-font-name = "Adwaita Mono Font 10";
          gtk-theme = "Adwaita-dark";
        };
      };

      programs.niri.package = pkgs.niri;

      programs.dank-material-shell = {
        enable = true;
	enableSystemMonitoring = true;
	dgop.package = inputs.dgop.packages.${pkgs.system}.default;
	systemd.enable = true;
	niri = {
	  enableKeybinds = true;
	};
      };
    };
  };
}
