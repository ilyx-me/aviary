{
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

    /*
    services.comin = {
      enable = true;
      remotes = [{
        name = "origin";
        url = "https://github.com/ilyx-me/aviary.git";
        branches.main.name = "dev-core-systems";
      }];
    };
    */

    system.autoUpgrade = {
      enable = true;
      flake = "github:ilyx-me/aviary/dev-core-systems";
      flags = [ "--no-write-lock-file" ];
      dates = "minutely";
      #randomizedDelaySec = "5min";
      #fixedRandomDelay = true;
      persistent = false;
    };

    systemd.services.nixos-upgrade.environment = {
      GIT_SSH_COMMAND = "ssh -i '/home/999/.ssh/id_ed25519' -o IdentitiesOnly=yes";
    };
  };
}
