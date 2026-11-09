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
    ;

  secrets = config.sops.secrets;
in
{

  config = {

    sops.secrets = {
      "cnt-kanidm-age" = {
        mode = "0400";
        owner = "kanidm-root";
        group = "kanidm-root";
      };
      "cnt-vaultwarden-age" = {
        mode = "0400";
        owner = "vaultwarden-root";
        group = "vaultwarden-root";
      };
    };

    environment.persistence."/persist".directories = [
      "/var/lib/nixos-containers/kanidm"
      "/var/lib/nixos-containers/vaultwarden"
    ];

    users = {
      groups = {
        "kanidm-root".gid = 524288;
        "vaultwarden-root".gid = 589824;
      };
      users = {
        "kanidm-root" = {
          isNormalUser = true;
          uid = 524288;
          group = "kanidm-root";
          shell = pkgs.shadow;
          home = "/var/empty";
        };
        "vaultwarden-root" = {
          isNormalUser = true;
          uid = 589824;
          group = "vaultwarden-root";
          shell = pkgs.shadow;
          home = "/var/empty";
        };
      };
    };

    systemd.network.networks = {
      "40-ve-kanidm" = {
        matchConfig.Name = "ve-kanidm";
        address = [ "172.16.0.1/24" ];
        networkConfig = {
          LinkLocalAddressing = "no";
          IPv6AcceptRA = "no";
        };
      };
      "40-ve-vaultwarden" = {
        matchConfig.Name = "ve-vaultwarden";
        address = [ "172.16.1.1/24" ];
        networkConfig = {
          LinkLocalAddressing = "no";
          IPv6AcceptRA = "no";
        };
      };
    };

    networking = {
      firewall.allowedTCPPorts = [ 443 8443 ];
      nat = {
        enable = true;
        internalInterfaces = [ "ve-+" ];
        externalInterface = "ens3";
        forwardPorts = [
          {
            sourcePort = 443;
            proto = "tcp";
            destination = "172.16.0.2:8443";
          }
          {
            sourcePort = 8443;
            proto = "tcp";
            destination = "172.16.1.2:8443";
          }
        ];

        # We want to translate traffic from tailscale aswell
        extraCommands = ''
          iptables -w -t nat -A nixos-nat-pre -i tailscale0 -p tcp --dport 443 \
            -j DNAT --to-destination 172.16.0.2:8443
          iptables -w -t nat -A nixos-nat-pre -i tailscale0 -p tcp --dport 8443 \
            -j DNAT --to-destination 172.16.1.2:8443
        '';
      };
    };

    containers.kanidm = {
      autoStart = true;
      privateUsers = 524288;
      extraFlags = [ "--private-users-ownership=map" ];
      privateNetwork = true;
      hostAddress = "172.16.0.1";
      localAddress = "172.16.0.2";

      bindMounts."cnt-kanidm-age" = {
        hostPath = secrets."cnt-kanidm-age".path;
        mountPoint = "/var/keys/age_host_key";
        isReadOnly = true;
      };

      config = { ... }: {
        imports = [ inputs.sops-nix.nixosModules.sops ];

        system.stateVersion = "26.05";

        sops = {
          age.keyFile = "/var/keys/age_host_key";
          defaultSopsFile = "${inputs.secrets}/container/kanidm.yaml";
          secrets = {
            "kanidm-cert-env" = {
              mode = "0400";
              owner = "kanidm";
              group = "kanidm";
            };
            "vaultwarden-sso" = {
              mode = "0400";
              owner = "kanidm";
              group = "kanidm";
            };
            "wireguard" = {
              mode = "0400";
              owner = "root";
              group = "root";
            };
          };
        };

        networking = {
          firewall.allowedTCPPorts = [ 8443 ];
          useHostResolvConf = lib.mkForce false;
          wireguard.interfaces."wg0" = {
            ips = [ "172.16.111.2/24" ];
            privateKeyFile = config.containers.kanidm.config.sops.secrets."wireguard".path;
            peers = [{
              publicKey = readFile "${inputs.secrets}/container/netbird/wireguard-pub";
              allowedIPs = [ "172.16.111.1/32" ];
              endpoint = "${readFile "${inputs.secrets}/container/netbird/netbird-cert-domain"}:51820";
              persistentKeepalive = 25;
            }];
          };
        };

        users.groups.kandim = { };

        security.acme = {
          acceptTerms = true;
          certs."kanidm" = {
            group = "kanidm";
            domain = readFile "${inputs.secrets}/${config.networking.hostName}/kanidm-cert-domain";
            email = readFile "${inputs.secrets}/${config.networking.hostName}/kanidm-cert-email";
            dnsProvider = "cloudflare";
            dnsResolver = "1.1.1.1:53";
            environmentFile = config.containers.kanidm.config.sops.secrets."kanidm-cert-env".path;
          };
        };

        services = {
          resolved.enable = true;

          kanidm = {
            package = pkgs.kanidmWithSecretProvisioning_1_11;
            provision = {
              enable = true;
              systems.oauth2."vaultwarden" = {
                displayName = "Vaultwarden";
                basicSecretFile = config.containers.kanidm.config.sops.secrets."vaultwarden-sso".path;
                originLanding = "https://${config.containers.vaultwarden.config.security.acme.certs.vaultwarden.domain}:8443";
                originUrl = "https://${config.containers.vaultwarden.config.security.acme.certs.vaultwarden.domain}:8443/identity/connect/oidc-signin";
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
                bindaddress = "0.0.0.0:8443";
                domain = config.containers.kanidm.config.security.acme.certs.kanidm.domain;
                origin = "https://${config.containers.kanidm.config.security.acme.certs.kanidm.domain}";
                tls_chain = "/var/lib/acme/kanidm/fullchain.pem";
                tls_key = "/var/lib/acme/kanidm/key.pem";
              };
            };
          };
        };
      };
    };

    containers.vaultwarden = {
      autoStart = true;
      privateUsers = 589824;
      extraFlags = [ "--private-users-ownership=map" ];
      privateNetwork = true;
      hostAddress = "172.16.1.1";
      localAddress = "172.16.1.2";

      bindMounts."cnt-vaultwarden-age" = {
        hostPath = secrets."cnt-vaultwarden-age".path;
        mountPoint = "/var/keys/age_host_key";
        isReadOnly = true;
      };

      config = { ... }: {
        imports = [ inputs.sops-nix.nixosModules.sops ];

        system.stateVersion = "26.05";

        sops = {
          age.keyFile = "/var/keys/age_host_key";
          defaultSopsFile = "${inputs.secrets}/container/vaultwarden.yaml";
          secrets = {
            "vaultwarden-cert-env" = {
              mode = "0400";
              owner = "vaultwarden";
              group = "vaultwarden";
            };
            "vaultwarden-env" = {
              mode = "0400";
              owner = "vaultwarden";
              group = "vaultwarden";
            };
          };
        };

        networking = {
          firewall.allowedTCPPorts = [ 8443 ];
          useHostResolvConf = lib.mkForce false;
        };

        users.groups.vaultwarden = { };

        security.acme = {
          acceptTerms = true;
          certs."vaultwarden" = {
            group = "vaultwarden";
            domain = readFile "${inputs.secrets}/${config.networking.hostName}/vaultwarden-cert-domain";
            email = readFile "${inputs.secrets}/${config.networking.hostName}/vaultwarden-cert-email";
            dnsProvider = "cloudflare";
            dnsResolver = "1.1.1.1:53";
            environmentFile = config.containers.vaultwarden.config.sops.secrets."vaultwarden-cert-env".path;
          };
        };

        services = {
          resolved.enable = true;
          vaultwarden = {
            enable = true;
            environmentFile = config.containers.vaultwarden.config.sops.secrets."vaultwarden-env".path; # SSO_CLIENT_SECRET
            config = {
              DOMAIN = "https://${config.containers.vaultwarden.config.security.acme.certs.vaultwarden.domain}:8443";
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
              SSO_AUTHORITY = "https://${config.containers.kanidm.config.security.acme.certs.kanidm.domain}/oauth2/openid/vaultwarden";
            };
          };
        };
      };
    };
  };
}
