{
  pkgs,
  ...
}:

{

  config = {

    nix.gc = {
      automatic = true;
      options = "--delete-generations 14d";
      dates = "02:00";
      randomizedDelaySec = "45min";
    };

    system.autoUpgrade = {
      enable = true;
      flake = "github:ilyx-me/aviary/dev-core-systems";
      flags = [ "--no-write-lock-file" ];
      dates = "hourly";
      #randomizedDelaySec = "5min";
      #fixedRandomDelay = true;
      persistent = false;
    };

    systemd.services.nixos-upgrade.environment = {
      GIT_SSH_COMMAND = "ssh -i '/home/999/.ssh/id_ed25519' -o IdentitiesOnly=yes";
    };

    systemd.services = {
      nixos-upgrade = {
        preStart = ''
	  mkdir -p -m 0755 /run/nixos-upgrade
	  umask 022
	  echo -n "nixos-upgrade-start" > /run/nixos-upgrade/status
        '';
        unitConfig = {
          OnFailure = "nixos-upgrade-failure.service";
          OnSuccess = "nixos-upgrade-success.service";
        };
      };

      "nixos-upgrade-failure".script = ''
        mkdir -p -m 0755 /run/nixos-upgrade
	umask 022
	echo -n "nixos-upgrade-failure" > /run/nixos-upgrade/status
      '';

      "nixos-upgrade-success".script = ''
        mkdir -p -m 0755 /run/nixos-upgrade
	umask 022
	echo -n "nixos-upgrade-success" > /run/nixos-upgrade/status
      '';
    };
  };
}
