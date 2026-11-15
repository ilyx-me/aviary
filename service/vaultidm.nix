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

  kanidmDomain = readFile "${inputs.secrets}/${config.networking.hostName}/kanidm-cert-domain";
  vaultwardenDomain = readFile "${inputs.secrets}/${config.networking.hostName}/vaultwarden-cert-domain";

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
      "kanidm-cert-env" = {
        mode = "0400";
        owner = "acme";
        group = "acme";
      };
      "vaultwarden-cert-env" = {
        mode = "0400";
        owner = "acme";
        group = "acme";
      };
    };

    environment.persistence."/persist".directories = [
      "/var/lib/acme"
    ];

    users = {
      groups = {
        "caddy-root".gid = 524288;
        "caddy-caddy".gid = 524527; # container gid 239
        "kanidm-root".gid = 589824;
        "kanidm-kanidm".gid = 590823; # container gid 999
        "vaultwarden-root".gid = 655360;
        "vaultwarden-vaultwarden".gid = 656356; # container gid 996
      };
      users = {
        "caddy-root" = {
          isNormalUser = true;
          uid = 524288;
          group = "caddy-root";
          shell = pkgs.shadow;
          home = "/var/empty";
        };
        "caddy-caddy" = {
          isNormalUser = true;
          uid = 524527; # container gid 239
          group = "caddy-caddy";
          shell = pkgs.shadow;
          home = "/var/empty";
        };
        "kanidm-root" = {
          isNormalUser = true;
          uid = 589824;
          group = "kanidm-root";
          shell = pkgs.shadow;
          home = "/var/empty";
        };
        "kanidm-kanidm" = {
          isNormalUser = true;
          uid = 590823; # container uid 999
          group = "kanidm-kanidm";
          shell = pkgs.shadow;
          home = "/var/empty";
        };
        "vaultwarden-root" = {
          isNormalUser = true;
          uid = 655360;
          group = "vaultwarden-root";
          shell = pkgs.shadow;
          home = "/var/empty";
        };
        "vaultwarden-vaultwarden" = {
          isNormalUser = true;
          uid = 656357; # container uid 997
          group = "vaultwarden-root";
          shell = pkgs.shadow;
          home = "/var/empty";
        };
      };
    };

    systemd.network.networks = {
      "40-ve-caddy" = {
        matchConfig.Name = "ve-caddy";
        address = [ "172.16.0.1/24" ];
        networkConfig = {
          LinkLocalAddressing = "no";
          IPv6AcceptRA = "no";
        };
      };
      "40-ve-kanidm" = {
        matchConfig.Name = "ve-kanidm";
        address = [ "172.16.1.1/24" ];
        networkConfig = {
          LinkLocalAddressing = "no";
          IPv6AcceptRA = "no";
        };
      };
      "40-ve-vaultwarden" = {
        matchConfig.Name = "ve-vaultwarden";
        address = [ "172.16.2.1/24" ];
        networkConfig = {
          LinkLocalAddressing = "no";
          IPv6AcceptRA = "no";
        };
      };
    };

    networking = {
      firewall = {
        allowedTCPPorts = [ 443 ];
        extraForwardRules = ''
          iifname "tailscale0" ip daddr 172.16.0.2 tcp dport 443 accept
        '';
      };
      nat = {
        enable = true;
        internalInterfaces = [ "ve-*" ];
        externalInterface = "ens3";
        forwardPorts = [{
          sourcePort = 443;
          proto = "tcp";
          destination = "172.16.0.2:443";
        }];
      };
      nftables.tables = {
        "tailscale-dnat" = {
          family = "ip";
          content = ''
            chain prerouting {
                type nat hook prerouting priority dstnat; policy accept;
                iifname "tailscale0" tcp dport 443 dnat to 172.16.0.2:443
            }
            chain postrouting {
                type nat hook postrouting priority srcnat; policy accept;
                oifname "ens3" masquerade
            }
          '';
        };
        "ve-nat" = {
          family = "inet";
          content = ''
            chain forward {
                type filter hook forward priority 0; policy accept;
                ct state invalid drop
                ct state established,related accept
                ip saddr 172.16.0.0/24 ip daddr 172.16.1.0/24 tcp dport 443 ct state new accept
                ip saddr 172.16.0.0/24 ip daddr 172.16.2.0/24 tcp dport 8080 ct state new accept
                ip saddr 172.16.2.0/24 ip daddr 172.16.1.0/24 tcp dport 443 ct state new accept
                ip saddr 172.16.0.0/24 ip daddr { 172.16.1.0/24, 172.16.2.0/24 } counter drop
                ip saddr 172.16.1.0/24 ip daddr { 172.16.0.0/24, 172.16.2.0/24 } counter drop
                ip saddr 172.16.2.0/24 ip daddr { 172.16.0.0/24, 172.16.1.0/24 } counter drop
            }
          '';
        };
      };
    };

    security.acme = {
      acceptTerms = true;
      certs = {
        "kanidm" = {
          domain = kanidmDomain;
          email = readFile "${inputs.secrets}/${config.networking.hostName}/kanidm-cert-email";
          dnsProvider = "cloudflare";
          dnsResolver = "1.1.1.1:53";
          environmentFile = config.sops.secrets."kanidm-cert-env".path;
          postRun = ''
            rm -f fullchain-caddy.pem key-caddy.pem
            cp -Lv fullchain.pem fullchain-caddy.pem
            cp -Lv key.pem key-caddy.pem
            chown caddy-caddy:caddy-caddy /var/lib/acme/kanidm/{fullchain-caddy,key-caddy}.pem
            rm -f fullchain-kanidm.pem key-kanidm.pem
            cp -Lv fullchain.pem fullchain-kanidm.pem
            cp -Lv key.pem key-kanidm.pem
            chown kanidm-kanidm:kanidm-kanidm /var/lib/acme/kanidm/{fullchain-kanidm,key-kanidm}.pem
          '';
          reloadServices = [ "container@caddy.service" "container@kanidm.service" ];
        };
        "vaultwarden" = {
          domain = vaultwardenDomain;
          email = readFile "${inputs.secrets}/${config.networking.hostName}/vaultwarden-cert-email";
          dnsProvider = "cloudflare";
          dnsResolver = "1.1.1.1:53";
          environmentFile = config.sops.secrets."vaultwarden-cert-env".path;
          postRun = ''
            rm -f fullchain-caddy.pem key-caddy.pem
            cp -Lv fullchain.pem fullchain-caddy.pem
            cp -Lv key.pem key-caddy.pem
            chown caddy-caddy:caddy-caddy /var/lib/acme/vaultwarden/{fullchain-caddy,key-caddy}.pem
          '';
          reloadServices = [ "container@caddy.service" ];
        };
      };
    };

    containers.caddy = {
      autoStart = true;
      ephemeral = true;
      privateUsers = 524288;
      extraFlags = [ "--private-users-ownership=map" ];
      privateNetwork = true;
      hostAddress = "172.16.0.1";
      localAddress = "172.16.0.2";

      bindMounts = {
        "kanidm-fullchain" = {
          hostPath = "/var/lib/acme/kanidm/fullchain-caddy.pem";
          mountPoint = "/var/lib/acme/kanidm/fullchain-caddy.pem";
          isReadOnly = true;
        };
        "kanidm-key" = {
          hostPath = "/var/lib/acme/kanidm/key-caddy.pem";
          mountPoint = "/var/lib/acme/kanidm/key-caddy.pem";
          isReadOnly = true;
        };
        "vaultwarden-fullchain" = {
          hostPath = "/var/lib/acme/vaultwarden/fullchain-caddy.pem";
          mountPoint = "/var/lib/acme/vaultwarden/fullchain-caddy.pem";
          isReadOnly = true;
        };
        "vaultwarden-key" = {
          hostPath = "/var/lib/acme/vaultwarden/key-caddy.pem";
          mountPoint = "/var/lib/acme/vaultwarden/key-caddy.pem";
          isReadOnly = true;
        };
      };


      config = { ... }: {
        system.stateVersion = config.system.nixos.release;

        environment.enableAllTerminfo = true;

        networking = {
          firewall.allowedTCPPorts = [ 443 ];
          useHostResolvConf = lib.mkForce false;
          hosts."172.16.1.2" = [ kanidmDomain ];
        };

        services = {
          resolved.enable = true;
          caddy = {
            enable = true;
            virtualHosts = {
              "${kanidmDomain}".extraConfig = ''
                reverse_proxy https://${kanidmDomain} {
                  header_down X-Real-IP {http.request.remote}
                  header_down X-Forwarded-For {http.request.remote}
                  transport http {
                    tls
                    tls_server_name ${kanidmDomain}
                  }
                }
                tls /var/lib/acme/kanidm/fullchain-caddy.pem /var/lib/acme/kanidm/key-caddy.pem {
                  protocols tls1.3
                }
              '';
              "${vaultwardenDomain}".extraConfig = ''
                reverse_proxy http://172.16.2.2:8080 {
                  header_down X-Real-IP {http.request.remote}
                  header_down X-Forwarded-For {http.request.remote}
                }
                tls /var/lib/acme/vaultwarden/fullchain-caddy.pem /var/lib/acme/vaultwarden/key-caddy.pem {
                  protocols tls1.3
                }
              '';
            };
          };
        };
      };
    };

    containers.kanidm = {
      autoStart = true;
      ephemeral = true;
      privateUsers = 589824;
      extraFlags = [ "--private-users-ownership=map" ];
      privateNetwork = true;
      hostAddress = "172.16.1.1";
      localAddress = "172.16.1.2";

      bindMounts = {
        "cnt-kanidm-age" = {
          hostPath = secrets."cnt-kanidm-age".path;
          mountPoint = "/var/keys/age_host_key";
          isReadOnly = true;
        };
        "kanidm-fullchain" = {
          hostPath = "/var/lib/acme/kanidm/fullchain-kanidm.pem";
          mountPoint = "/var/lib/acme/kanidm/fullchain-kanidm.pem";
          isReadOnly = true;
        };
        "kanidm-key" = {
          hostPath = "/var/lib/acme/kanidm/key-kanidm.pem";
          mountPoint = "/var/lib/acme/kanidm/key-kanidm.pem";
          isReadOnly = true;
        };
        "kanidm-data" = {
          hostPath = "/srv/kanidm";
          mountPoint = "/var/lib/kanidm";
          isReadOnly = false;
        };
      };

      config = { ... }: {
        imports = [ inputs.sops-nix.nixosModules.sops ];

        system.stateVersion = config.system.nixos.release;

        environment.enableAllTerminfo = true;

        sops = {
          age.keyFile = "/var/keys/age_host_key";
          defaultSopsFile = "${inputs.secrets}/container/kanidm.yaml";
          secrets = {
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
          firewall.allowedTCPPorts = [ 443 ];
          useHostResolvConf = lib.mkForce false;
          hosts."172.16.2.2" = [ vaultwardenDomain ];
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

        services = {
          resolved.enable = true;

          kanidm = {
            package = pkgs.kanidmWithSecretProvisioning_1_11;
            provision = {
              enable = true;
              systems.oauth2."vaultwarden" = {
                displayName = "Vaultwarden";
                basicSecretFile = config.containers.kanidm.config.sops.secrets."vaultwarden-sso".path;
                originLanding = "https://${vaultwardenDomain}";
                originUrl = "https://${vaultwardenDomain}/identity/connect/oidc-signin";
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
                bindaddress = "0.0.0.0:443";
                domain = kanidmDomain;
                origin = "https://${kanidmDomain}";
                tls_chain = "/var/lib/acme/kanidm/fullchain-kanidm.pem";
                tls_key = "/var/lib/acme/kanidm/key-kanidm.pem";
              };
            };
          };
        };
      };
    };

    containers.vaultwarden = {
      autoStart = true;
      ephemeral = true;
      privateUsers = 655360;
      extraFlags = [ "--private-users-ownership=map" ];
      privateNetwork = true;
      hostAddress = "172.16.2.1";
      localAddress = "172.16.2.2";

      bindMounts = {
        "cnt-vaultwarden-age" = {
          hostPath = secrets."cnt-vaultwarden-age".path;
          mountPoint = "/var/keys/age_host_key";
          isReadOnly = true;
        };
        "vaultwarden-data" = {
          hostPath = "/srv/vaultwarden";
          mountPoint = "/var/lib/vaultwarden";
          isReadOnly = false;
        };
      };

      config = { ... }: {
        imports = [ inputs.sops-nix.nixosModules.sops ];

        system.stateVersion = config.system.nixos.release;

        environment.enableAllTerminfo = true;

        sops = {
          age.keyFile = "/var/keys/age_host_key";
          defaultSopsFile = "${inputs.secrets}/container/vaultwarden.yaml";
          secrets."vaultwarden-env" = {
            mode = "0400";
            owner = "vaultwarden";
            group = "vaultwarden";
          };
        };

        networking = {
          firewall.allowedTCPPorts = [ 8080 ];
          useHostResolvConf = lib.mkForce false;
          hosts."172.16.1.2" = [ kanidmDomain ];
        };

        services = {
          resolved.enable = true;
          vaultwarden = {
            enable = true;
            environmentFile = config.containers.vaultwarden.config.sops.secrets."vaultwarden-env".path; # SSO_CLIENT_SECRET
            config = {
              DOMAIN = "https://${vaultwardenDomain}";
              EMAIL_CHANGE_ALLOWED = false;
              INVITATIONS_ALLOWED = false;
              PASSWORD_HINTS_ALLOWED = false;
              ROCKET_ADDRESS = "0.0.0.0";
              ROCKET_PORT = 8080;
              SENDS_ALLOWED = true;
              SSO_ENABLED = true;
              SSO_CLIENT_ID = "vaultwarden";
              SSO_ONLY = true;
              SSO_SIGNUPS_MATCH_EMAIL = false;
              SSO_AUTHORITY = "https://${kanidmDomain}/oauth2/openid/vaultwarden";
            };
          };
        };
      };
    };
  };
}
