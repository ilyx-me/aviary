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

in {

  config = 

  let

    secrets = toString inputs.secrets;

    defaultPermissions = {
      mode = "0440";
      owner = config.users.users."1000".name;
      group = "admin";
    };

    u00-chicken = readFile "${secrets}/00/chicken-ssh-user-pub";

  in {

    sops = {
      defaultSopsFile = "${secrets}/00.yaml";
      secrets = {
        "egg-luks" = defaultPermissions;
        #"egg-ssh-admin" = defaultPermissions;
        "egg-ssh-host" = defaultPermissions;
        #"egg-ssh-user" = {
        #  mode = "0400";
        #  owner = config.users.users."1000".name;
        #  group = "admin";
        #};
        #"egg-ts" = defaultPermissions;
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
        userName = readFile "${secrets}/${config.aviary.uID}/username-git";
        userEmail = readFile "${secrets}/${config.aviary.uID}/email-git";
      };

      home.packages = with pkgs; mkIf config.aviary.graphical [
        #davinci-resolve-studio
      ];
    };
  };
}
