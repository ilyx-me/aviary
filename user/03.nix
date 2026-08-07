{
  inputs,
  ...
}:

let
  inherit (builtins)
    toString
    ;

  secrets = toString inputs.secrets;

in
{

  config = {

    sops.defaultSopsFile = "${secrets}/03.yaml";

    aviary.uID = "03";

    home-manager.users."1000" = { };
  };
}
