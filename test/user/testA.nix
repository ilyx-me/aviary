{
  inputs,
  lib,
  ...
}:

let
  inherit (builtins)
    readFile
    ;

in
{

  config = {

    environment.etc."age_host_key" = {
      text = readFile "${inputs.secrets-test}/test-a/test-a-age";
      mode = "0400";
    };

    sops = {
      age.keyFile = lib.mkVMOverride "/etc/age_host_key";
      defaultSopsFile = "${inputs.secrets-test}/test-a.yaml";
      /*
        secrets."test-a-ssh-root" = {
          mode = "0400";
          owner = "root";
          group = "root";
          path = "/root/.ssh/id_ed25519";
        };
      */
    };

    users.groups."1000" = {};
    users.users."1000" = {
      name = "user";
      group = "1000";
      hashedPassword = "";
      isNormalUser = true;
    };

    system.nixos.variant_id = "test";
    networking.hostName = "test-a";
    aviary.primaryUuid = "test-a";
    aviary.primaryGid = "1000";
    aviary.uID = "test-a";

    boot.initrd.network.ssh.authorizedKeys = [ "none" ];
  };
}
