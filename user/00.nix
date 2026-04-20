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

    home-manager.users."1000" = {

      programs.git = {
        enable = true;
        settings.user = {
          name = readFile "${secrets}/${config.aviary.uID}/username-git";
          email = readFile "${secrets}/${config.aviary.uID}/email-git";
	};
      };

      home.packages = with pkgs; mkIf config.aviary.graphical [
        #davinci-resolve-studio
      ];
    };
  };
}
