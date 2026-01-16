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

    services.fwupd.enable = true;

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
      flags = [];
      dates = "minutely";
    };
  };
}
