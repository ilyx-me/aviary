{
  config,
  inputs,
  lib,
  pkgs,
  utils,
  ...
}:

let
  inherit (builtins)
    readFile
    pathExists
    ;

  inherit (lib)
    foldl'
    listToAttrs
    mkDefault
    mkForce
    mkIf
    mkOption
    nameValuePair
    optional
    sortOn
    ;

  inherit (lib.attrsets)
    attrsToList
    ;

  inherit (lib.types)
    bool
    nullOr
    str
    ;

  inherit (pkgs)
    writeShellScript
    ;

  inherit (utils)
    escapeSystemdPath
    ;

  host = config.networking.hostName;

  # UID keys for user map lookups and sops secret references
  adminUid = "999";
  primaryUid = "1000";

  pcr15 = config.aviary.pcr15;

  secrets = config.sops.secrets;
  secretsName = config.aviary.secrets;

  # Drive name resolved once, reused for both luks device paths
  driveSuffix =
    if pathExists /tmp/aviaryInstall/egg-drive-name then
      readFile /tmp/aviaryInstall/egg-drive-name
    else
      host;

  deviceDiskPrimary = "disk-primary-luks-${driveSuffix}";
  deviceMapperPrimary = "disk-primary-luks-btrfs-${driveSuffix}";

  cryptsetupEarlyExecStart = writeShellScript "cryptsetup-early" (
    readFile ../../script/systemd/cryptsetupEarly.sh
  );

  impermanenceExecStart = writeShellScript "impermanence" (
    readFile ../../script/systemd/impermanence.sh
  );

  pcrExecStart = writeShellScript "pcr15Check" (readFile ../../script/systemd/pcr15Check.sh);

  systemdPath = config.boot.initrd.systemd.package;

  u00-chicken = readFile "${inputs.secrets}/00/chicken-ssh-user-pub";
  u00-ibis = readFile "${inputs.secrets}/00/ibis-ssh-user-pub";

in
{

  options.aviary = {

    graphical = mkOption {
      type = bool;
      default = false;
      example = true;
      description = "Graphical environment flag";
    };

    # All credit for cryptsetup pcr15 check goes to patrick
    # https://forge.lel.lol/patrick/nix-config/src/branch/master/modules/ensure-pcr.nix
    pcr15 = mkOption {
      type = nullOr str;
      default = null;
      example = "6214de8c3d861c4b451acc8c4e24294c95d55bcec516bbf15c077ca3bffb6547";
      description = ''
        The expected value of PCR 15 after all luks partitions have been unlocked
        Should be a 64 character hex string as output by the sha256 field of
        'systemd-analyze pcrs 15 --json=short'
        If set to null (the default) it will not check the value.
        If the check fails the boot will abort and you will be dropped into an
        emergency shell, if enabled.
        In emergency shell type:
        'systemctl disable check-pcrs'
        'systemctl default'
        to continue booting
      '';
    };

    uID = mkOption {
      type = nullOr str;
      default = null;
      example = "00";
      description = "Aviary user ID for primary system user";
    };

    secrets = {

      description = mkOption {
        type = str;
        default = "description";
        example = "Username";
        description = "Private file storing the user description";
      };

      luksRecovery = mkOption {
        type = str;
        default = host + "-luks";
        example = "hostname-luks";
        description = "SOPS-Nix secret storing the recovery password for LUKS";
      };

      passwordHash = mkOption {
        type = str;
        default = "password-hash";
        example = "user-password-hash";
        description = "SOPS-Nix secret storing the user password hash";
      };

      stateVersion = mkOption {
        type = str;
        default = host + "-state-version";
        example = "hostname-state-version";
        description = "Private file storing the system stateversion";
      };

      sshAdmin = mkOption {
        type = str;
        default = host + "-ssh-admin";
        example = "hostname-ssh-admin";
        description = "SOPS-Nix secret storing the admin SSH private key";
      };

      sshAdminPub = mkOption {
        type = str;
        default = host + "-ssh-admin-pub";
        example = "hostname-ssh-admin-pub";
        description = "Private file storing the admin SSH public key";
      };

      sshUser = mkOption {
        type = str;
        default = host + "-ssh-user";
        example = "hostname-ssh-user";
        description = "SOPS-Nix secret storing the user SSH private key";
      };

      username = mkOption {
        type = str;
        default = "username";
        example = "user-username";
        description = "Private file storing the user username";
      };
    };
  };

  config = {

    documentation.doc.enable = false;
    hardware.enableAllFirmware = true;
    nix.channel.enable = false;
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    nix.settings.trusted-users = [
      "root"
      "${config.users.users.${adminUid}.name}"
      "@wheel"
    ];

    sops = {

      age.keyFile = "/persist/var/keys/age_host_key";

      secrets = {

        ${secretsName.sshAdmin} = mkForce {
          mode = "0400";
          owner = config.users.users.${adminUid}.name;
          group = "admins";
          path = "/home/${adminUid}/.ssh/id_ed25519";
        };

        ${secretsName.sshUser} = mkForce {
          mode = "0400";
          owner = config.users.users.${primaryUid}.name;
          group = "admins";
          path = "/home/${primaryUid}/.ssh/id_ed25519";
        };

        ${secretsName.luksRecovery} = {
          mode = "0440";
          owner = config.users.users.${primaryUid}.name;
          group = "admins";
          restartUnits = [ "syncluksrecovery.service" ];
        };

        ${secretsName.passwordHash} = {
          neededForUsers = true;
          mode = "0440";
          owner = config.users.users.${primaryUid}.name;
          group = "admins";
        };
      };
    };

    nixpkgs.config = mkIf (config.system.nixos.variant_id != "test") {
      allowUnfree = true;
    };

    system.stateVersion = mkDefault config.system.nixos.release;

    fileSystems."/persist".neededForBoot = true;

    environment.persistence."/persist" = {

      hideMounts = true;

      directories = [
        "/etc/nixos"
        "/var/log"
        "/var/lib/kanidm-unixd"
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
      ];

      files = [
        "/etc/machine-id"
        "/etc/ssh/ssh_host_ed25519_key"
        "/var/keys/age_host_key"
      ];
    };

    boot.initrd.systemd = {

      enable = true;

      services = {

        systemd-ask-password-console.wantedBy = [ "cryptsetup.target" ];

        "check-pcrs" = mkIf (pcr15 != null) {
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pcrExecStart} ${pcr15}";
          };
          unitConfig.DefaultDependencies = "no";
          after = [ "cryptsetup.target" ];
          before = [ "sysroot.mount" ];
          requiredBy = [ "sysroot.mount" ];
        };

        "impermanence" = {
          unitConfig.DefaultDependencies = "no";
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${impermanenceExecStart} ${deviceMapperPrimary}";
          };
          after = [ "systemd-makefs@dev-mapper-${escapeSystemdPath deviceMapperPrimary}.service" ]; # For runNixOSTest
          before = [ "sysroot.mount" ];
          wants = [ "systemd-makefs@dev-mapper-${escapeSystemdPath deviceMapperPrimary}.service" ]; # For runNixOSTest
          wantedBy = [ "cryptsetup.target" ];
        };

        "systemd-cryptsetup-early" = {
          unitConfig = {
            Description = "Early cryptography setup for ${deviceMapperPrimary}";
            DefaultDependencies = "no";
            IgnoreOnIsolate = true;
            Conflicts = [ "umount.target" ];
            BindsTo = [
              "dev-disk-${escapeSystemdPath "by-partlabel"}-${escapeSystemdPath deviceDiskPrimary}.device"
            ];
          };
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            TimeoutSec = "infinity";
            KeyringMode = "shared";
            OOMScoreAdjust = 500;
            ImportCredential = "cryptsetup.*";
            ExecStart = "${cryptsetupEarlyExecStart} ${systemdPath} ${deviceMapperPrimary} ${deviceDiskPrimary} discard,headless,tpm2-device=auto,tpm2-measure-pcr=yes";
          };
          after = [
            "cryptsetup-pre.target"
            "systemd-udevd-kernel.socket"
            "dev-disk-${escapeSystemdPath "by-partlabel"}-${escapeSystemdPath deviceDiskPrimary}.device"
          ]
          ++ (optional config.boot.initrd.systemd.tpm2.enable "systemd-tpm2-setup-early.service");
          before = [
            "blockdev@dev-mapper-${deviceMapperPrimary}.target"
            "cryptsetup.target"
            "umount.target"
            "wpa_supplicant-initrd.service"
          ];
          wants = [ "blockdev@dev-mapper-${deviceMapperPrimary}.target" ];
          requiredBy = [
            "sysroot.mount"
            "wpa_supplicant-initrd.service"
          ];
        };
      }
      // (listToAttrs (
        foldl' (
          acc: attrs:
          [
            (nameValuePair "systemd-cryptsetup@${escapeSystemdPath attrs.name}" {
              overrideStrategy = "asDropin";

              after = [
                "wpa_supplicant-initrd.service"
              ]
              ++ optional (acc != [ ]) "${(builtins.head acc).name}.service";

              before = [ "impermanence.service" ];

              requiredBy = [ "impermanence.service" ];
              requires = [ "wpa_supplicant-initrd.service" ];

              wants = [ "network-online.target" ];
            })
          ]
          ++ acc
        ) [ ] (sortOn (x: x.name) (attrsToList config.boot.initrd.luks.devices))
      ));

      storePaths = [
        impermanenceExecStart
        cryptsetupEarlyExecStart
        pcrExecStart
      ];
    };

    security = {
      sudo.enable = false;
      doas = {
        enable = true;
        extraRules = [
          {
            groups = [ "wheel" ];
            keepEnv = true;
            persist = true;
          }

          {
            users = [ config.users.users.${adminUid}.name ];
            keepEnv = true;
            noPass = true;
          }
        ];
      };
    };

    i18n = {
      defaultLocale = "en_US.UTF-8";
      extraLocaleSettings = {
        # LC_MEASUREMENT does not follow defaultLocale for US-style units
        LC_MEASUREMENT = "en_US.UTF-8";
      };
    };

    networking.useNetworkd = true;

    environment = {
      enableAllTerminfo = true;
      systemPackages = with pkgs; [
        age
        btop
        disko
        efitools
        jq
        linux-firmware
        nixos-anywhere
        rsync
        sbctl
        sbsigntool
        shpool
        sops
        tio
      ];
    };

    programs = {
      git = {
        enable = true;
        config.safe.directory = [
          "/home/${adminUid}/aviary"
          "/home/${primaryUid}/aviary"
        ];
      };
      nano.enable = false;
      neovim = {
        enable = true;
        defaultEditor = true;
        viAlias = true;
        vimAlias = true;
      };
    };

    systemd = {
      enableEmergencyMode = false;
      tmpfiles.rules = [
        "d /home/${primaryUid}/.ssh 0700 ${config.users.users.${primaryUid}.name} users -"
        "L /home/${config.users.users.${primaryUid}.name} 0777 root root - /home/${primaryUid}"
        "d /home/${adminUid} 0700 ${config.users.users.${adminUid}.name} admins -"
        "d /home/${adminUid}/.ssh 0700 ${config.users.users.${adminUid}.name} admins -"
        "L /home/${config.users.users.${adminUid}.name} 0777 root root - /home/${adminUid}"
      ];

      services = {

        "tpm-auto-enroll" = {
          after = [ "multi-user.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };

          unitConfig.ConditionPathExists = "/var/lib/sbctl/keys";

          script = ''
            if [ "$(od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-* | tr -d ' ')" -eq 60001 ]; then
                /run/current-system/sw/bin/systemd-cryptenroll /dev/disk/by-partlabel/disk-primary-luks-${host} --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=7 --unlock-key-file=/run/secrets/${host}-luks

                if [ -e "/dev/disk/by-partlabel/disk-secondary-luks-${host}" ]; then
                    /run/current-system/sw/bin/systemd-cryptenroll /dev/disk/by-partlabel/disk-secondary-luks-${host} --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=7 --unlock-key-file=/run/secrets/${host}-luks
                fi
            fi
          '';
        };
      };
    };

    services = {

      fwupd.enable = true;
      timesyncd.enable = false;

      kanidm = {

        package = pkgs.kanidmWithSecretProvisioning_1_10;

        client = {
          enable = true;
          settings.uri =
            if config.system.nixos.variant_id == "test" then
              "https://idm.example.invalid"
            else
              "https://${readFile "${inputs.secrets}/00/kanidm-cert-domain"}";
        };

        unix = {
          enable = true;
          settings = {
            default_shell = "/run/current-system/sw/bin/bash";
            kanidm = {
              pam_allowed_login_groups = [ "users" ];
              map_group = [
                {
                  local = "wheel";
                  "with" = "admins";
                }
                {
                  local = "networkmanager";
                  "with" = "users";
                }
                {
                  local = "uinput";
                  "with" = "users";
                }
              ];
            };
          };
        };
      };

      ntpd-rs = {
        enable = true;
        settings.observability.log-level = "warn";
      };
    };

    users = {

      groups."admins" = { };
      mutableUsers = false;

      users = {

        root = {
          description = mkForce "root";
        };

        ${adminUid} = {
          isSystemUser = true;
          name = "admin";
          description = "Admin";
          extraGroups = [ "wheel" ];
          group = "admins";
          useDefaultShell = true;
          hashedPasswordFile = secrets.${secretsName.passwordHash}.path;
          openssh.authorizedKeys.keys =
            if config.system.nixos.variant_id == "test" then
              [ "none" ]
            else
              [
                u00-chicken
                u00-ibis
              ];
          home = "/home/${adminUid}";
        };

        ${primaryUid} = {
          isNormalUser = true;
          name =
            if config.system.nixos.variant_id == "test" then
              "user"
            else
              readFile "${inputs.secrets}/${config.aviary.uID}/${secretsName.username}";
          description =
            if config.system.nixos.variant_id == "test" then
              "User"
            else
              readFile "${inputs.secrets}/${config.aviary.uID}/${secretsName.description}";
          uid = 1000;
          hashedPasswordFile = secrets.${secretsName.passwordHash}.path;
          home = "/home/${primaryUid}";
        };
      };
    };

    home-manager = {

      extraSpecialArgs = { inherit inputs; };

      users.${primaryUid} = {

        home = {
          homeDirectory = "/home/${primaryUid}";
          stateVersion = config.system.stateVersion;
          username = config.users.users.${primaryUid}.name;
        };

        programs.home-manager.enable = true;
      };
    };
  };
}
