# MANUAL CONFIGURATION

### Secureboot Enrollment

Secureboot enrollment is automatic with Lanzaboot via `generate-sb-keys.service`. On the first boot of the system, lanzaboot will create the secureboot keys, reboot the system, enroll them and reboot again. This works on most systems so long as the UEFI firmware is in secureboot setup mode (usually a separate option or automatically toggled when secureboot is off) however some older systems may need to have this done manually so consult your specific firmware documentation.

Lanzaboot will attempt to put the secureboot keys into the EFI partition at `/boot/loader/keys/auto` but you can also find them at `/var/lib/sbctl` on the root filesystem.

### TPM Decryption

TPM decription is automatically set up after Secureboot keys are enrolled via `tpm-auto-enroll.service`. Manually enrolling setting up TPM decription can be done like so:

```bash
systemd-cryptenroll /dev/disk/by-partlabel/disk-primary-luks-<hostname> --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=7
```

Make sure to change `<hostname>` to match your system.

# TESTING

### Batch

```bash
nix flake check
```

### Individual

Where `<test>` is the name of the test to run and `<arch>` is one of the following:

 - `aarch64-darwin`
 - `aarch64-linux`
 - `x86_64-darwin`
 - `x86_64-linux`

```bash
nix run -L .#checks.<arch>.<test>.driver            # Automatic
nix run -L .#checks.<arch>.<test>.driverInteractive # Debug
```

### Test Debugging

Run a test with the interactive driver then use the following commands to interact with the machines. You can use `machines[1]` for `<machine>` to get the `booted_machine` when running diskoLib tests.

```python
run_tests()                # Begins test execution, akin to running the automatic driver above
exit()                     # Stop the interactive driver

<machine>.start()          # Start a virtual machine
<machine>.shutdown()       # Stop a virtual machine
<machine>.shell_interact() # Shell access for a virtual machine, ctrl+d to return to python
```

For more see the [complete list of commands](https://nixos.org/manual/nixos/stable/index.html#ssec-machine-objects).

# IMPLEMENTED TESTS

### General

 - [x] UEFI boot
 - [x] secureboot
 - [x] TPM2 measured boot
 - [x] PCR15 checked boot
 - [x] persistant files
 - [x] secrets
 - [x] reach multi-user.target
 - [x] network (ssh + tailscale)
 - [ ] wifi (via services.vwifi)
 - [ ] automatic updates

### Initrd

 - [x] network (ssh + tailscale)
 - [ ] wifi (services.vwifi?)
 - [x] LUKS decryption (over ssh)

### Debug

 - [x] initrd f9 tty
 - [x] root, admin, and user login
 - [ ] recovery deployment

### Formating
 - [x] recovery
 - [x] single
 - [ ] singleQuota
 - [ ] double
 - [ ] redundant

# TODO

 - separate private from secrets in environment/default
 - remaining tests
   - automatic updates
   - recovery deployment
   - singleQuota
 - Get first boot to DMS without niri flicker
 - Add separate PW for 999
 - default mime types
   - folders, web sites, music, video, images
 - auto updates
 - dms black overview background
 - flatpak auto updates
