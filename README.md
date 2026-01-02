# MANUAL CONFIGURATION

### Secureboot Enrollment

Note: For this to work, the device needs to be in secureboot setup mode.
For most devices, this is enabled on the first boot after enabling
secureboot in the UEFI settings but this may also be firmware specific.

```bash
sbctl enroll-keys --microsoft
```

### TPM2 Enrollment

```bash
systemd-cryptenroll /dev/disk/by-partlabel/disk-primary-luks-hostname --tpm2-device=auto --tpm2-pcrs=0+2+4+7
```

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

Run a test in the above interactive mode then use the following
commands to interact with the machines.

Hint: use `machines[1]` for `<machine>` to get the `booted_machine`
when running diskoLib tests.

```python
run_tests()                # Begins test execution, akin to running the automatic driver above
exit()                     # Stop the interactive driver

<machine>.start()          # Start a virtual machine
<machine>.shutdown()       # Stop a virtual machine
<machine>.shell_interact() # Shell access for a virtual machine, ctrl+d to return to python
```

For more see the [complete list of commands](https://nixos.org/manual/nixos/stable/index.html#ssec-machine-objects).

# TESTING TODO

### General

[x] UEFI boot
[x] secureboot
[x] TPM2 measured boot
[x] PCR15 checked boot
[ ] persistant files
[ ] secrets
[x] reach multi-user.target
[x] network (ssh + tailscale)
[ ] automatic updates (comin)

### Initrd

[ ] wifi (services.vwifi?)
[x] network (ssh + tailscale)
[x] LUKS decryption (over ssh)

### Debug

[x] initrd f9 tty
[x] root, admin, and user login
[ ] recovery deployment

### Formating
[x] recovery
[x] single
[ ] singleQuota
[ ] double
[ ] redundant

# TODO

- /home/admin perms to admin:admin
- move impermance script to separate unit to stop mount /sysroot race condition
- automatic secureboot enrollment
