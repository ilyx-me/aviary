# TESTING

Where `<test>` is the name of the test to run and `<arch>` is one of the following:

- `aarch64-darwin`
- `aarch64-linux`
- `x86_64-darwin`
- `x86_64-linux`

### Automatic

```bash
nix run -L .#checks.<arch>.<test>.driver
```

### Debug

```bash
nix run -L .#checks.<arch>.<test>.driverInteractive
```
