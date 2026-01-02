{
  inputs,
  ...
}:

let
  inherit (builtins)
    readFile
    ;
in {

  config = {
    environment.etc."ssh/ssh_host_ed25519_key" = {
      text = readFile "${inputs.secrets-test}/test-a/test-a-ssh-host";
      mode = "0400";
    };

    sops.defaultSopsFile = "${inputs.secrets-test}/test-a.yaml";

    system.nixos.variant_id = "test";
    networking.hostName = "test-a";
    aviary.uID = "test-a";

    boot.initrd.network.ssh.authorizedKeys = [ "none" ];
  };
}
