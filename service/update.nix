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

    services.comin = {
      enable = true;
      remotes = [{
        name = "origin";
        url = "https://github.com/ilyx-me/aviary.git";
        branches.main.name = "main";
      }];
    };
  };
}
