{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit ( builtins )
    readFile
    toString
  ;

  inherit ( lib )
    mkIf
  ;

  secrets = toString inputs.secrets;

  defaultPermissions = {
    mode = "0440";
    owner = config.users.users."1000".name;
    group = "admins";
  };

  u00-chicken = readFile "${secrets}/00/chicken-ssh-user-pub";

in {

  config = {

    sops = {
      defaultSopsFile = "${secrets}/00.yaml";

      # <hostname>-age and <hostname>-luks must exist on the machine that deploys hostname
      secrets = {
        "egg-age" = defaultPermissions;
        "egg-luks" = defaultPermissions;

        "ibis-age" = defaultPermissions;
        "ibis-luks" = defaultPermissions;
      };
    };

    aviary.uID = "00";

    users.users."1000" = {
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [ u00-chicken ];
    };

    programs.firefox.policies.ExtensionSettings = {

      # Unhook
      "myallychou@gmail.com" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/youtube-recommended-videos/latest.xpi";
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

    home-manager.users."1000" = {

      imports = [
        inputs.nixvim.homeModules.nixvim
        ./module/nvim.nix
        ./module/starship.nix
      ];

      programs = {
        ghostty.settings.gtk-tabs-location = "hidden";
        git = {
          enable = true;
          settings.user = {
            name = readFile "${secrets}/${config.aviary.uID}/username-git";
            email = readFile "${secrets}/${config.aviary.uID}/email-git";
          };
        };

        librewolf = {
          profiles."default".userChrome = lib.mkForce ''
            @import "firefox-gnome-theme/userChrome.css";
            
            /* Hide tabs entirely */
            #TabsToolbar {
                visibility: collapse !important;
            }
          '';

          /*
          settings = {
            "browser.link.open_newwindow" = 1;                   # Open links for 'new windows' in same tab
            "browser.link.open_newwindow.override.external" = 2; # Open links from external apps in a new window
          };
          */
        };
      };

      home.packages = with pkgs; mkIf config.aviary.graphical [
        #davinci-resolve-studio
      ];
    };
  };
}
