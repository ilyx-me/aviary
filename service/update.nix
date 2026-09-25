{
  config,
  pkgs,
  ...
}:

let

  inherit (builtins)
    readFile
    ;

  inherit (pkgs)
    writeShellScript
    ;

  nixosUpgradeChecks = writeShellScript "nixos-upgrade-checks.sh" (
    readFile ../script/systemd/nixosUpgradeChecks.sh
  );

  nixosUpgradeFailure = writeShellScript "nixos-upgrade-failure.sh" (
    readFile ../script/systemd/nixosUpgradeFailure.sh
  );

  nixosUpgradeSuccess = writeShellScript "nixos-upgrade-success.sh" (
    readFile ../script/systemd/nixosUpgradeSuccess.sh
  );
in
{

  config = {

    nix.gc = {
      automatic = true;
      options = "--delete-generations 14d";
      dates = "02:00";
      randomizedDelaySec = "45min";
    };

    system.autoUpgrade = {
      #enable = true;
      flake = "github:ilyx-me/aviary/main";
      flags = [ "--no-write-lock-file" ];
      dates = "hourly";
      #randomizedDelaySec = "5min";
      #fixedRandomDelay = true;
      persistent = false;
    };

    systemd.tmpfiles.rules = [
      "d /run/nixos-upgrade 0755 root root - -"
      "f /run/nixos-upgrade/status 0644 root root - -"
    ];

    programs.ssh.knownHosts."github.com".publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

    systemd.services = {
      nixos-upgrade = {
        environment = {
          GIT_SSH_COMMAND = "${pkgs.openssh}/bin/ssh -i '/run/secrets/${config.aviary.secrets.sshAdmin}' -o IdentitiesOnly=yes";
        };
        serviceConfig.ExecStartPre = "${nixosUpgradeChecks} ${pkgs.git} ${pkgs.coreutils}";
        unitConfig = {
          OnFailure = "nixos-upgrade-failure.service";
          OnSuccess = "nixos-upgrade-success.service";
        };
      };

      "nixos-upgrade-failure".serviceConfig.ExecStart = "${nixosUpgradeFailure}";
      "nixos-upgrade-success".serviceConfig.ExecStart = "${nixosUpgradeSuccess} ${pkgs.coreutils}";
    };
  };
}
