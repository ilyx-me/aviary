{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (builtins)
    readFile
    toString
    ;

  inherit (lib)
    mkIf
    ;

  secrets = toString inputs.secrets;

in
{

  config = {

    sops.defaultSopsFile = "${secrets}/${config.aviary.primaryGid}.yaml";

    aviary.primaryUuid = "ae8a2a01-92a6-42a2-a0db-03ab51874ffd";
    aviary.primaryGid = "1904693245";

    services.syncthing.settings = {
      devices = {
        "cardinal".id = readFile "${inputs.secrets}/${config.aviary.primaryGid}/cardinal-st-id";
        "chicken".id = readFile "${inputs.secrets}/${config.aviary.primaryGid}/chicken-st-id";
        "ibis".id = readFile "${inputs.secrets}/${config.aviary.primaryGid}/ibis-st-id";
      };
      folders = {
        "Documents".devices = [
          "cardinal"
          "chicken"
          "ibis"
        ];
        "Music".devices = [
          "cardinal"
          "chicken"
          "ibis"
        ];
        "Pictures".devices = [
          "cardinal"
          "chicken"
          "ibis"
        ];
        "Templates".devices = [
          "cardinal"
          "chicken"
          "ibis"
        ];
        "Videos".devices = [
          "cardinal"
          "chicken"
          "ibis"
        ];
      };
    };

    programs.firefox.policies.ExtensionSettings = {

      # Unhook
      "myallychou@gmail.com" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/youtube-recommended-videos/latest.xpi";
        installation_mode = "normal_installed";
      };

      # Vimium
      "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/vimium-ff/latest.xpi";
        installation_mode = "normal_installed";
      };

      # No Tabs
      "{c9f848fb-3fb6-4390-9fc1-e4dd4d1c5122}" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/adsum-notabs/latest.xpi";
        installation_mode = "normal_installed";
      };

      # Open external links in a container
      "{f069aec0-43c5-4bbf-b6b4-df95c4326b98}" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/open-url-in-container/latest.xpi";
        installation_mode = "normal_installed";
      };
    };
  };
}
