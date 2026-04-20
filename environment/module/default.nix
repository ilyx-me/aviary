{
  config,
  inputs,
  lib,
  pkgs,
  utils,
  ...
}:

let
  inherit ( builtins )
    head
    readFile
    pathExists
  ;

  inherit ( lib )
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

  inherit ( lib.attrsets )
    attrsToList
  ;

  inherit ( lib.types )
    bool
    nullOr
    str
  ;

  inherit ( pkgs )
    writeShellScript
  ;

  inherit ( utils )
    escapeSystemdPath
  ;

  host = config.networking.hostName;

  pcr15 = config.aviary.pcr15;

  secrets = config.sops.secrets;
  secretsName = config.aviary.secrets;

  deviceDiskPrimary = if pathExists /tmp/egg-drive-name then "disk-primary-luks-${readFile /tmp/egg-drive-name}" else "disk-primary-luks-${host}";
  deviceMapperPrimary = if pathExists /tmp/egg-drive-name then "disk-primary-luks-btrfs-${readFile /tmp/egg-drive-name}" else "disk-primary-luks-btrfs-${host}";

  cryptsetupEarlyExecStart = writeShellScript "cryptsetup-early" (
    readFile ../../script/systemd/cryptsetupEarly.sh
  );

  cryptsetupExecStartPost = writeShellScript "impermanence" (
    readFile ../../script/systemd/impermanence.sh
  );

  pcrExecStart = writeShellScript "pcr15Check" (
    readFile ../../script/systemd/pcr15Check.sh
  );

  systemdPath = config.boot.initrd.systemd.package;

in {

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
        Should be a 64 character hex string as ouput by the sha256 field of
        'systemd-analyze pcrs 15 --json=short'
        If set to null (the default) it will not check the value.
        If the check fails the boot will abort and you will be dropped into an
        emergency shell, if enabled.
        In ermergency shell type:
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
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nix.settings.trusted-users = [ "root" "${config.users.users."999".name}" "@wheel" ];

    sops = {

      validateSopsFiles = false;
      age = {
        # sshKeyPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
        keyFile = "/persist/var/keys/age_host_key";
        # generateKey = true;
      };

      secrets = {

        ${secretsName.sshAdmin} = mkForce {
          mode = "0400";
          owner = config.users.users."999".name;
          group = "admins";
          path = "/home/999/.ssh/id_ed25519";
        };

        ${secretsName.sshUser} = mkForce {
          mode = "0400";
          owner = config.users.users."1000".name;
          group = "admins";
          path = "/home/1000/.ssh/id_ed25519";
        };

        ${secretsName.luksRecovery} = {
          mode = "0440";
          owner = config.users.users."1000".name;
          group = "admins";
          restartUnits = [ "syncluksrecovery.service" ];
        };

        ${secretsName.passwordHash} = {
          neededForUsers = true;
          mode = "0440";
          owner = config.users.users."1000".name;
          group = "admins";
          restartUnits = [ "syncluks.service" ];
        };
      };
    };

    nixpkgs.config = lib.mkIf (config.system.nixos.variant_id != "test") {
      allowUnfree = true;
    };

    system.stateVersion = mkDefault config.system.nixos.release;

    fileSystems."/persist".neededForBoot = true;

    environment.persistence."/persist" = {

      hideMounts = true;

      directories = [
        "/etc/nixos"
        "/var/log"
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

        # Attempt to fix /sysroot dir not being created in time
        # create-needed-for-boot-dirs.wantedBy = [ "sysroot.mount" ];

        systemd-ask-password-console.wantedBy = [ "cryptsetup.target" ];

        "check-pcrs" = mkIf ( pcr15 != null ) {
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
            ExecStart = "${cryptsetupExecStartPost} ${deviceMapperPrimary}";
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
            BindsTo = [ "dev-disk-${escapeSystemdPath "by-partlabel"}-${escapeSystemdPath deviceDiskPrimary}.device" ];
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
          ++ ( optional config.boot.initrd.systemd.tpm2.enable "systemd-tpm2-setup-early.service" );
          before = [
            "blockdev@dev-mapper-${deviceMapperPrimary}.target"
            "cryptsetup.target"
            "umount.target"
            "wpa_supplicant-initrd.service"
          ];
          wants = [ "blockdev@dev-mapper-${deviceMapperPrimary}.target" ];
          requiredBy = [ "sysroot.mount" "wpa_supplicant-initrd.service" ];
        };
      }
      // ( listToAttrs (
        foldl' (
          acc: attrs:
          [
            ( nameValuePair "systemd-cryptsetup@${escapeSystemdPath attrs.name}" {
                overrideStrategy = "asDropin";

                after = [
                  "wpa_supplicant-initrd.service"
                ] ++ optional ( acc != [ ] ) "${( head acc ).name}.service";

                before = [ "impermanence.service" ];

                requiredBy = [ "impermanence.service" ];
                requires = [ "wpa_supplicant-initrd.service" ];

                wants = [ "network-online.target" ];
              }
            )
          ]
          ++ acc
        ) [ ] ( sortOn ( x: x.name ) ( attrsToList config.boot.initrd.luks.devices ) )
      ));

      storePaths = [
        cryptsetupExecStartPost
        cryptsetupEarlyExecStart
        pcrExecStart
      ];
    };

    /*
    security.sudo = {

      extraConfig = "Defaults lecture=never";

      extraRules = [

        {
          users = [ "${config.users.users."999".name}" ];
          commands = [

            {
              command = "ALL";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
    };
    */

    security = {
      sudo.enable = false;
      doas ={
        enable = true;
	extraRules = [
	  {
	    groups = [ "wheel" ];
	    keepEnv = true;
	    persist = true;
	  }

	  {
	    users = [ config.users.users."999".name ];
	    keepEnv = true;
	    noPass = true;
	  }
	];
      };
    };

    i18n = {
      defaultLocale = "en_US.UTF-8";
      extraLocaleSettings = {
        LC_ADDRESS = "en_US.UTF-8";
        LC_IDENTIFICATION = "en_US.UTF-8";
        LC_MEASUREMENT = "en_US.UTF-8";
        LC_MONETARY = "en_US.UTF-8";
        LC_NAME = "en_US.UTF-8";
        LC_NUMERIC = "en_US.UTF-8";
        LC_PAPER = "en_US.UTF-8";
        LC_TELEPHONE = "en_US.UTF-8";
        LC_TIME = "en_US.UTF-8";
      };
    };

    networking.useNetworkd = true;

    environment.systemPackages = with pkgs; [
      age
      disko
      doas-sudo-shim
      efitools
      git
      jq
      linux-firmware
      nixos-anywhere
      rsync
      sbctl
      sbsigntool
      shpool
      sops
      ssh-to-age
      tio
    ];

    programs = {
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
        "d /home/1000/.ssh 0700 ${config.users.users."1000".name} users -"
        "L /home/${config.users.users."1000".name} 0777 root root - /home/1000"
        "d /home/999 0700 ${config.users.users."999".name} admins -"
        "d /home/999/.ssh 0700 ${config.users.users."999".name} admins -"
        "L /home/${config.users.users."999".name} 0777 root root - /home/999"
      ];

      services = {
        #generate-sb-keys.after = [ "tpm-auto-enroll.service" ];

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
	    fi
	  '';
	};
      };
    };

    services = {
      fwupd.enable = true;
      timesyncd.enable = false;
      ntpd-rs.enable = true;
    };

    users = {

      groups."admins" = { };
      mutableUsers = false;

      users = {

        root = {
          description = mkForce "root";
          openssh.authorizedKeys.keys = if config.system.nixos.variant_id == "test" then [ "none" ]
            else [ (readFile "${inputs.secrets}/${config.aviary.uID}/${secretsName.sshAdminPub}") ];
        };

        "999" = {
          isSystemUser = true;
          name = "admin";
          description = "Admin";
          extraGroups = [ "wheel" ];
          group = "admins";
          useDefaultShell = true;
          hashedPasswordFile = secrets.${secretsName.passwordHash}.path;
          home = "/home/999";
        };

        "1000" = {
          isNormalUser = true;
          name = if config.system.nixos.variant_id == "test" then "user"
            else readFile "${inputs.secrets}/${config.aviary.uID}/${secretsName.username}";
          description = if config.system.nixos.variant_id == "test" then "User"
            else readFile "${inputs.secrets}/${config.aviary.uID}/${secretsName.description}";
          uid = 1000;
          hashedPasswordFile = secrets.${secretsName.passwordHash}.path;
          home = "/home/1000";
        };
      };
    };

    home-manager = {

      extraSpecialArgs = { inherit inputs; };

      users."1000" = {

        home = {
          homeDirectory = config.users.users."1000".home;
          stateVersion = config.system.stateVersion;
          username = config.users.users."1000".name;
        };

        programs.home-manager.enable = true;
      };
    };
  };
}
