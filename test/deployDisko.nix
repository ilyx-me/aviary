{
  inputs,
  lib,
  pkgs,
  self',
  ...
}: let

  inherit (builtins)
    readFile
    ;

  inherit (lib)
    recursiveUpdate
    ;

  config = { networking.hostName = "test-a"; };
  default = (import ../system/module/part/default.nix { inherit config lib; }).config;
  single = (import ../system/module/part/single.nix { }).config;
  diskoConfig = recursiveUpdate default single;
in {
  pkgs = pkgs;
  name = "deploy-test";
  enableOCR = true;

  disko-config = diskoConfig;

  extraInstallerConfig = {
    systemd.tmpfiles.settings."10-luks-pwd"."/luks-password-recovery".f.argument = "password";

    #environment.systemPackages = [
    #  pkgs.sbctl
    #];
  };

  extraSystemConfig = {
    _module.args = { inherit inputs; };
    imports = [
      inputs.comin.nixosModules.comin
      inputs.disko.nixosModules.default
      inputs.home-manager.nixosModules.default
      inputs.impermanence.nixosModules.impermanence
      inputs.lanzaboote.nixosModules.lanzaboote
      inputs.sops-nix.nixosModules.sops
      #../environment/module/bootstrap.nix
      ../environment/module/default.nix
      ../environment/module/recovery.nix
      ../service/default.nix
      ../environment/module/debug.nix # TODO remove me
    ];

    #virtualisation.memorySize = 7168; # 3072;
    #virtualisation.diskSize = 4096; # 32768; # In case kernel needs to be built
    #virtualisation.emptyDiskImages = [16384]; # [49152];
    #virtualisation.useEFIBoot = true;

    sops = {
      secrets = {
        "test-a-ssh-user" = lib.mkVMOverride {
          mode = "0400";
          owner = "root";
          group = "root";
          path = "/root/.ssh/id_ed25519";
        };
      };
    };

    environment.etc."ssh/ssh_host_ed25519_key" = {
      text = readFile "${inputs.secrets-test}/test-a/test-a-ssh-host";
      mode = "0400";
    };

    systemd.tmpfiles.rules = ["d /root/.ssh 0700 root root -"];

    users.users.root.openssh.authorizedKeys.keys = [ (readFile "${inputs.secrets-test}/test-a/test-a-ssh-user-pub") ];

    networking.hostName = "test-a";

    system.nixos.variant_id = "test";

    boot.initrd.network.ssh.authorizedKeys = [ "none" ];

    sops.defaultSopsFile = "${toString inputs.secrets-test}/test-a.yaml";

    aviary.uID = "test-a";

    systemd.services."wpa_supplicant-recovery".enable = false;
  };

  #postDisko = readFile ./check/defaultInstall.py;
  bootCommands = readFile ./check/defaultInitrd.py;

  extraTestScript = ''
    # Ensure nixos-anywhere deployment works
    machine.copy_from_host("/home/1000/aviary/", "/tmp/") # TODO This path needs to be dehardcoded but challenging
    machine.execute("echo password > /luks-password-recovery")
    machine.execute("echo -n '/dev/vdb' > /tmp/egg-drive")
    machine.execute("nixos-anywhere -f ./aviary#deploy-test --option pure-eval false --phases disko,install root@localhost", True, False, None)

    # Clean up tailscale ephemeral node
    machine.execute("tailscale logout")
  '';
}
