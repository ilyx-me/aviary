# Copy pastad from:
#https://github.com/pioner14/Waydroid_on_NixOS/blob/main/Waydroid_Setup_Guide.md#9-critical-production-ready-configuration-updated-2026-01-27
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # IMPORTANT: Find your Intel GPU path with: ls -l /dev/dri/by-path/ | grep pci-.*-render
  # Usually: pci-0000:00:02.0-render (Intel is typically at 00:02.0)
  intelRenderNode = "/dev/dri/by-path/pci-0000:00:02.0-render";
in
{
  virtualisation.waydroid.enable = true;
  virtualisation.waydroid.package = pkgs.waydroid-nftables;

  # Network configuration
  networking.firewall.trustedInterfaces = [ "waydroid0" ];
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.conf.all.forwarding" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # Enhance default service (NO lib.mkForce to avoid breaking network/cgroups!)
  systemd.services.waydroid-container = {
    serviceConfig = {
      # Enable cgroups v2 delegation (fixes "Read-only file system" errors)
      Delegate = true;
      CPUAccounting = true;
      MemoryAccounting = true;
      TasksAccounting = true;

      # GPU fix runs BEFORE container starts (no race conditions)
      ExecStartPre = lib.mkAfter [
        (pkgs.writeShellScript "waydroid-gpu-fix-pre" ''
          set -e
          PROP_FILE="/var/lib/waydroid/waydroid.prop"

          mkdir -p /var/lib/waydroid
          touch "$PROP_FILE"
          chown root:root "$PROP_FILE"
          chmod 644 "$PROP_FILE"

          # Function to set properties (removes old, adds new)
          set_prop() {
            ${pkgs.gnused}/bin/sed -i "/^$1=/d" "$PROP_FILE"
            echo "$1=$2" >> "$PROP_FILE"
          }

          # Force Intel GPU (GBM/Mesa)
          set_prop ro.hardware.gralloc gbm
          set_prop ro.hardware.egl mesa
          set_prop gralloc.gbm.device ${intelRenderNode}
          set_prop ro.hardware.vulkan intel

          # Clean empty lines
          ${pkgs.gnused}/bin/sed -i '/^$/d' "$PROP_FILE"
        '')
      ];
    };
  };

  # Backup persistence service (runs after start as fallback)
  systemd.services.waydroid-gpu-persistence = {
    description = "Enforce Intel GPU for Waydroid (Post-Start Backup)";
    after = [ "waydroid-container.service" ];
    bindsTo = [ "waydroid-container.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "waydroid-intel-fix-post" ''
        set -e
        ${pkgs.coreutils}/bin/sleep 5
        ${config.virtualisation.waydroid.package}/bin/waydroid prop set ro.hardware.gralloc gbm
        ${config.virtualisation.waydroid.package}/bin/waydroid prop set ro.hardware.egl mesa
        ${config.virtualisation.waydroid.package}/bin/waydroid prop set gralloc.gbm.device ${intelRenderNode}
        ${config.virtualisation.waydroid.package}/bin/waydroid prop set ro.hardware.vulkan intel
      '';
    };
  };

  environment.systemPackages = [ pkgs.waydroid-helper ];

  home-manager.users."1000" = {
    systemd.user.services.waydroid-session = {
      Unit = {
        Description = "Waydroid User Session";
        After = [ "waydroid-container.service" ];
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.waydroid-nftables}/bin/waydroid session start";
        ExecStop = "${pkgs.waydroid-nftables}/bin/waydroid session stop";

        # Clean up processes on exit
        KillMode = "mixed";

        # Resource limits: 4GB Max, 3GB cache threshold
        MemoryMax = "4G";
        MemoryHigh = "3G";

        TimeoutStopSec = "15s";
        Restart = "on-failure";
      };
    };
  };
}
