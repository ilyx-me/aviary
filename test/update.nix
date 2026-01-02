{
  inputs,
  lib,
  self',
  ...
}:

let
  inherit (builtins)
    readFile
    ;

  config = self'.checks.update.nodes.machine;
in
{
  name = "update";

  node.specialArgs = { inherit inputs; };

  nodes.machine = { ... }: {
    imports = [
      inputs.comin.nixosModules.comin
      #inputs.impermanence.nixosModules.impermanence
      inputs.sops-nix.nixosModules.sops
      ../service/update.nix
    ];

    environment.etc."ssh/ssh_host_ed25519_key" = {
      text = readFile "${inputs.secrets-test}/test-a/test-a-ssh-host";
      mode = "0400";
    };

    sops.defaultSopsFile = "${toString inputs.secrets-test}/test-a.yaml";

    system.nixos.variant_id = "test";

    #boot.initrd.network.ssh.authorizedKeys = [ "none" ];

    networking.hostName = "test-a";

    #aviary.uID = "test-a";

    users.groups.admin = {};
    users.users.admin.group = "admin";
    users.users.admin.isSystemUser = true;
    users.users."1000".group = "users";
    users.users."1000".isNormalUser = true;
    users.users."1000".name = "user";
  };

  testScript = readFile ./check/update.py;
}
