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
	  revision_repo=$(/run/current-system/sw/bin/git ls-remote https://github.com/ilyx-me/aviary dev-core-systems | /run/current-system/sw/bin/cut -f1)
	  revision_system=$(/run/current-system/sw/bin/nixos-version --configuration-revision)

	  mkdir -p -m 0755 /run/nixos-upgrade
	  umask 022

	  if [[ "$revision_system" == "$revision_repo" ]]; then
	      echo "System revision matches repository revision, exiting..."
	      echo -n "nixos-upgrade-skip" > /run/nixos-upgrade/status
	      exit 1
	  fi

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

	upgrade_status=$(cat "/run/nixos-upgrade/status" 2>/dev/null || echo -n "")

	if [[ "$upgrade_status" == "nixos-upgrade-skip" ]]; then
	    exit 0
	fi

	echo -n "nixos-upgrade-failure" > /run/nixos-upgrade/status
      '';

      "nixos-upgrade-success".script = ''
        mkdir -p -m 0755 /run/nixos-upgrade
	umask 022

	booted="$(/run/current-system/sw/bin/readlink /run/booted-system/{initrd,kernel,kernel-modules})"
	built="$(/run/current-system/sw/bin/readlink /nix/var/nix/profiles/system/{initrd,kernel,kernel-modules})"

	if [ "''${booted}" = "''${built}" ]; then
	    echo -n "nixos-upgrade-reboot" > /run/nixos-upgrade/status
	else
	    echo -n "nixos-upgrade-success" > /run/nixos-upgrade/status
	fi
      '';
    };
  };
}
