{
  config,
  inputs,
  lib,
  ...
}:

let
  inherit (builtins)
    toString
    ;

  inherit (lib)
    readFile
    ;

  secrets = toString inputs.secrets;

in
{

  config = {

    sops.defaultSopsFile = "${secrets}/${config.aviary.primaryGid}.yaml";

    aviary.primaryUuid = "d57d7b35-8566-40ce-8f9e-54bbe6a4ca99";
    aviary.primaryGid = "1990511257";

    services.syncthing.settings = {
      devices = {
        "quail".id = readFile "${inputs.secrets}/${config.aviary.primaryGid}/quail-st-id";
      };
      folders = {
        "Documents".devices = [
          "quail"
        ];
        "Music".devices = [
          "quail"
        ];
        "Pictures".devices = [
          "quail"
        ];
        "Templates".devices = [
          "quail"
        ];
        "Videos".devices = [
          "quail"
        ];
      };
    };
  };
}
