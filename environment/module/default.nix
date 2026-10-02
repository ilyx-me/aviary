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

  cryptsetupEarlyExecStart = writeShellScript "cryptsetup-early.sh" (
    readFile ../../script/systemd/cryptsetupEarly.sh
  );

  impermanenceExecStart = writeShellScript "impermanence.sh" (
    readFile ../../script/systemd/impermanence.sh
  );

  pcrExecStart = writeShellScript "pcr15-check.sh" (
    readFile ../../script/systemd/pcr15Check.sh
  );

  tpmAutoEnrollExecStart = writeShellScript "tpm-auto-enroll.sh" (
    readFile ../../script/systemd/tpmAutoEnroll.sh
  );

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

    primaryUuid = mkOption {
      type = nullOr str;
      default = null;
      example = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX";
      description = "Kanidm uuid for the primary system user";
    };

    primaryGid = mkOption {
      type = nullOr str;
      default = null;
      example = 1904693246;
      description = "Kanidm gid for the primary system user";
    };

    secrets = {

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
    };
  };

  config = {

    documentation.doc.enable = false;
    hardware.enableAllFirmware = true;
    nix.channel.enable = false;
    nix = {
      settings = {
        accept-flake-config = true;
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        trusted-users = [
          "root"
          "${config.users.users.${adminUid}.name}"
          "@wheel"
        ];
      };
    };

    sops = {

      age.keyFile = "/persist/var/keys/age_host_key";

      secrets = {

        ${secretsName.sshAdmin} = mkForce {
          mode = "0400";
          owner = config.users.users.${adminUid}.name;
          group = "admins";
          path = "/home/${adminUid}/.ssh/id_ed25519";
        };

        ${secretsName.luksRecovery} = {
          mode = "0440";
          owner = "root";
          group = "admins";
          restartUnits = [ "syncluksrecovery.service" ];
        };

        ${secretsName.passwordHash} = {
          neededForUsers = true;
          mode = "0440";
          owner = "root";
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
        "/var/cache/kanidm-unixd"
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
      fish = {
        enable = true;
        interactiveShellInit = ''
          set -g fish_greeting
          cd ~
        '';
      };
      git = {
        enable = true;
        config.safe.directory = [
          "/home/${adminUid}/aviary"
          "/home/${config.aviary.primaryUuid}/aviary"
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
        "d /home/${adminUid} 0700 ${config.users.users.${adminUid}.name} admins - -"
        "d /home/${adminUid}/.ssh 0700 ${config.users.users.${adminUid}.name} admins - -"
        "L /home/${config.users.users.${adminUid}.name} 0777 root root - /home/${adminUid}"
        "d /home/${config.aviary.primaryUuid} 0750 ${config.aviary.primaryGid} ${config.aviary.primaryGid} - -"
      ];

      services = {

        "tpm-auto-enroll" = {
          after = [ "multi-user.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${tpmAutoEnrollExecStart} ${pkgs.systemd} ${host}";
          };
          unitConfig.ConditionPathExists = "/var/lib/sbctl/keys";
        };

        kanidm-unixd = {
          before = [ "getty.target" "greetd.service" ];
          wants = [ "getty.target" "greetd.service" ];
        };

        "hjem-activate@" = {
          after = [ "kanidm-unixd.service" ];
          before = [ "getty.target" "greetd.service" ];
          wants = [ "kanidm-unixd.service" "getty.target" "greetd.service" ];
        };
      };
    };

    services = {

      fwupd.enable = true;
      timesyncd.enable = false;

      kanidm = {

        package = pkgs.kanidmWithSecretProvisioning_1_11;

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
            default_shell = "${pkgs.fish}/bin/fish";
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
      defaultUserShell = pkgs.fish;

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
      };
    };

    hjem = {
      clobberByDefault = true;
      users = {
        ${adminUid}.directory = "${config.users.defaultUserHome}/${adminUid}";
        ${config.aviary.primaryGid} = {
          externalIdp = true;
          directory = "${config.users.defaultUserHome}/${config.aviary.primaryUuid}";
        };
      };
    };
  };
}
