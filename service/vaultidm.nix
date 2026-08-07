{
  config,
  inputs,
  ...
}:

let

  inherit (builtins)
    readFile
    ;

  secrets = config.sops.secrets;
in
{

  config = {

    sops.secrets = {
      "kanidm-cert-env" = {
        mode = "0440";
        owner = "root";
        group = "admins";
      };
      "vaultwarden-cert-env" = {
        mode = "0440";
        owner = "root";
        group = "admins";
      };
      "vaultwarden-env" = {
        mode = "0440";
        owner = "vaultwarden";
        group = "admins";
      };
      "vaultwarden-sso" = {
        mode = "0440";
        owner = "kanidm";
        group = "admins";
      };
    };

    environment.persistence."/persist".directories = [
      "/var/lib/acme"
      "/var/lib/kanidm"
      "/var/lib/vaultwarden"
    ];

    security.acme = {

      acceptTerms = true;
      certs = {

        "kanidm" = {
          group = "kanidm";
          domain = readFile "${inputs.secrets}/${config.aviary.uID}/kanidm-cert-domain";
          email = readFile "${inputs.secrets}/${config.aviary.uID}/kanidm-cert-email";
          dnsProvider = "cloudflare";
          dnsResolver = "1.1.1.1:53";
          environmentFile = secrets."kanidm-cert-env".path;
        };

        "vaultwarden" = {
          group = "vaultwarden";
          domain = readFile "${inputs.secrets}/${config.aviary.uID}/vaultwarden-cert-domain";
          email = readFile "${inputs.secrets}/${config.aviary.uID}/vaultwarden-cert-email";
          dnsProvider = "cloudflare";
          dnsResolver = "1.1.1.1:53";
          environmentFile = secrets."vaultwarden-cert-env".path;
        };
      };
    };

    services = {

      kanidm = {

        provision = {
          enable = true;
          systems.oauth2."vaultwarden" = {
            displayName = "Vaultwarden";
            basicSecretFile = secrets."vaultwarden-sso".path;
            originLanding = "https://${config.security.acme.certs.vaultwarden.domain}:8443";
            originUrl = "https://${config.security.acme.certs.vaultwarden.domain}:8443/identity/connect/oidc-signin";
            scopeMaps."users" = [
              "openid"
              "email"
              "profile"
            ];
          };
          groups."users".overwriteMembers = false;
          groups."admins".overwriteMembers = false;
        };

        server = {
          enable = true;
          settings = {
            bindaddress = "[::]:443";
            domain = config.security.acme.certs.kanidm.domain;
            origin = "https://${config.security.acme.certs.kanidm.domain}";
            tls_chain = "/var/lib/acme/kanidm/fullchain.pem";
            tls_key = "/var/lib/acme/kanidm/key.pem";
          };
        };
      };

      vaultwarden = {

        enable = true;
        environmentFile = secrets."vaultwarden-env".path; # SSO_CLIENT_SECRET
        config = {
          DOMAIN = "https://${config.security.acme.certs.vaultwarden.domain}:8443";
          EMAIL_CHANGE_ALLOWED = false;
          INVITATIONS_ALLOWED = false;
          PASSWORD_HINTS_ALLOWED = false;
          ROCKET_ADDRESS = "0.0.0.0";
          ROCKET_PORT = 8443;
          ROCKET_TLS = ''{certs="/var/lib/acme/vaultwarden/fullchain.pem",key="/var/lib/acme/vaultwarden/key.pem"}'';
          SENDS_ALLOWED = true;
          SSO_ENABLED = true;
          SSO_CLIENT_ID = "vaultwarden";
          SSO_ONLY = true;
          SSO_SIGNUPS_MATCH_EMAIL = false;
          SSO_AUTHORITY = "https://${config.security.acme.certs.kanidm.domain}/oauth2/openid/vaultwarden";
        };
      };
    };
  };
}
