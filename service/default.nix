{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit ( builtins )
    readFile
    pathExists
  ;

  inherit ( lib )
    mkOption
  ;

  inherit ( lib.types )
    str
  ;

  inherit ( pkgs )
    writeShellScript
  ;

  host = config.networking.hostName;
  secrets = config.sops.secrets;
  secretsName = config.aviary.secrets;
  defaultPermissions = {
    mode = "0440";
    owner = config.users.users."1000".name;
    group = "admins";
  };

  wpaExecStart = writeShellScript "initrdwificonnect" ( readFile ../script/systemd/initrdwifi.sh );

in {

  options.aviary = {

    secrets = {

      ts = mkOption {
        type = str;
        default = host + "-ts";
        example = "hostname-ts";
        description = "SOPS-Nix secret storing tailscale key";
      };

      tsInitrd = mkOption {
        type = str;
        default = host + "-ts-initrd";
        example = "hostname-ts-initrd";
        description = "Private file storing tailscale initrd key";
      };
    };
  };

  config = {

    sops.secrets = {

      "${secretsName.ts}" = defaultPermissions;

    };

    boot.initrd = {

      availableKernelModules = [ "ccm" "ctr" "tun" ];

      network = {
        enable = true;

        ssh = {
          enable = true;
          extraConfig = "HostKey /etc/ssh/ssh_host_ed25519_key";
          authorizedKeys = config.users.users."1000".openssh.authorizedKeys.keys;
          ignoreEmptyHostKeys = true; # We're deploying keys out of band.

          # Using a different port prevents ssh clients from throwing MITM error.
          port = 2222;
        };
      };

      systemd = {

        tmpfiles.settings = {

          # Copy the ts key into initrd.
          #
          # This exposes the key to everyone on the system via nix store or
          # anyone with physical access to the system which is why we use a
          # different tailscale key from the main system and
          # ENSURE THIS KEY IS COMPLETELY LOCKED DOWN VIA TAILSCALE ACLS.
          "20-ts"."/run/secretsInitrd/ts-initrd".f = {
            group = "root";
            mode = "0400";
            user = "root";
            argument = if config.system.nixos.variant_id == "test" then readFile "${inputs.secrets-test}/${config.aviary.uID}/${host}-ts-initrd"
              else readFile "${inputs.secrets}/${config.aviary.uID}/${host}-ts-initrd";
          };

          # Link the dbus socket to where tailscaled expects it
          "50-tailescale"."/var/run".d = {
            argument = "/run";
            type = "L";
          };
        };

        packages = [ pkgs.wpa_supplicant pkgs.tailscale pkgs.openssh ];
        initrdBin = [ pkgs.wpa_supplicant pkgs.tailscale pkgs.openssh ];

        dbus.enable = true;
        sockets.dbus.unitConfig.DefaultDependencies = "no"; # Not set up by dbus.enable = true;

        users.root.shell = "/bin/systemd-tty-ask-password-agent";

        network.links."10-wifi" = {
          matchConfig.Type = "wlan";
          linkConfig.Name = "wifi0";
        };

        targets.cryptsetup.wants = [ "wpa_supplicant-initrd.service" ];

        services = {
          sshd = {
            wantedBy = [ "systemd-ask-password-console.service" ];
            preStart = ''
              ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N "" -q
            '';
          };

          "wpa_supplicant@".enable = false;

          "wpa_supplicant-initrd" = {
            description = "WPA supplicant daemon (for interface wifi0)";
            before = [ "network.target" ];
            wants = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];

            serviceConfig = {
              ExecStart = if pathExists /tmp/egg-drive-name then "${wpaExecStart} disk-primary-luks-btrfs-${readFile /tmp/egg-drive-name}" else "${wpaExecStart} disk-primary-luks-btrfs-${host}";
              TimeoutStartSec = 0;
              Type = "notify";
              NotifyAccess = "main";
            };

            unitConfig.DefaultDependencies = false;
          };

          dbus.unitConfig.DefaultDependencies = "no"; # Not set up by dbus.enable = true;

          tailscaled = {
            wants = [ "dbus.service" "network-online.target" ];
            wantedBy = [ "cryptsetup.target" ];
            unitConfig.DefaultDependencies = "no";
            serviceConfig = {
              TimeoutSec = "infinity";
              Environment = [
                "PORT=${toString config.services.tailscale.port}"
                "FLAGS=\"--tun ${config.services.tailscale.interfaceName}\""
              ];
            };
            postStart = ''
              authKey="$(cat /run/secretsInitrd/ts-initrd)"
              tailscale up -authkey "$authKey"
            '';
            preStop = "/run/current-system/sw/bin/tailscale logout";
          };
        };

        storePaths = [ wpaExecStart ];
      };
    };

    environment.persistence."/persist".directories = [
      "/var/lib/tailscale"
    ];

    #systemd.services.systemd-networkd-wait-online.enable = mkForce false; # Sometimes this fires after initrd

    # Disabling these might be a bad idea but
    # these are tricky to get working in initrd and throw a [Depend] during boot
    #systemd.services.systemd-networkd-persistent-storage.enable = false; # Persists mac address accross reboots
    #systemd.services.network-local-commands.enable = false; # Hook for custom network commands

    systemd.services.tailscaled = {
      after = [ "systemd-networkd.service" "multi-user.target" ];
      preStop = "/run/current-system/sw/bin/tailscale logout";
    };

    systemd.services.tailscaled-autoconnect.after = [ "multi-user.target" ];

    networking.firewall.allowedTCPPorts = [ 22 ];

    services = {
      openssh = {
        enable = true;
        ports = [ 22 ];
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          UseDns = true;
          PermitRootLogin = "prohibit-password";
        };

        hostKeys = [
          {
            path = "/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
      };

      tailscale = {
        enable = true;
        authKeyFile = secrets.${secretsName.ts}.path;
        useRoutingFeatures = "client";
      };
    };

    # Prevent GUI for inputting SSH credentials
    programs.ssh.askPassword = "";
  };
}
