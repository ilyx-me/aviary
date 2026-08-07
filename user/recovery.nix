{
  config,
  inputs,
  lib,
  ...
}:

let
  secrets = builtins.toString inputs.secrets;

  admin-ibis = builtins.readFile "${secrets}/00/ibis-ssh-admin-pub";
  admin-chicken = builtins.readFile "${secrets}/00/chicken-ssh-admin-pub";

in
{

  config = {

    sops = {
      defaultSopsFile = "${secrets}/recovery.yaml";
    };

    aviary.uID = "recovery";

    boot.initrd.network.ssh.authorizedKeys =
      lib.mkForce
        config.users.users."999".openssh.authorizedKeys.keys;

    users.users = {

      root.openssh.authorizedKeys.keys = config.users.users."999".openssh.authorizedKeys.keys;
      "999".openssh.authorizedKeys.keys = [
        admin-ibis
        admin-chicken
      ];
      "1000".hashedPasswordFile = lib.mkForce null;
    };
  };
}
