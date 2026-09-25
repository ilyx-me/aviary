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

    aviary.primaryUuid = "d57d7b35-8566-40ce-8f9e-54bbe6a4ca99";
    aviary.primaryGid = "1990511257";
    aviary.uID = "03";
  };
}
