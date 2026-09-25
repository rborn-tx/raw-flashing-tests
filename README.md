# raw-flashing-tests

Automated tests for the U-Boot fastboot and memory-protection features used
when flashing raw images onto Toradex modules. The tests are written with
[BATS](https://github.com/bats-core/bats-core) and drive the device over USB
through NXP's `uuu` and, for some tests, the standard `fastboot` tool.

The suites in `tests/` cover:

- `fastboot.bats`: fastboot buffer address protection and the fastboot
  commands used for flashing (`getvar`, `download`, `flash`, `erase`, `boot`,
  `reboot`, `set_active`, and the `oem` commands).
- `cp.bats`: the U-Boot hardening checks that make `cp` refuse to read or
  write outside the accessible RAM range, for every access size. The RAM range
  is read from `bdinfo`, so the tests do not hard-code addresses.

The image under test can be a Toradex Easy Installer image (with a
`recovery/` directory) or a package built by the flashing tool from
meta-toradex-flasher (with a `flash/` directory).

## Usage

Install the BATS repositories into `bats/` (set `CLEAN_INSTALL=1` to
re-clone them):

```
./setup.sh
```

Run the tests as root, passing the directory of the unpacked image:

```
sudo ./run.sh <image-dir>
```

Put the device into recovery mode when prompted. JUnit reports are written to
`reports/`.

Environment variables accepted by `run.sh`:

- `TESTS`: test files to run (default: `tests/*.bats`).
- `BATS_ARGS`: arguments passed to `bats`.
- `BATS_VERBOSE=1`: show the output of passing tests.
- `SERCAP_CMD`: command that captures the U-Boot serial console, e.g.
  `nc localhost 2004` with a `ser2net` port attached to the device's console.
  Tests that check U-Boot error messages are skipped or relaxed when unset.
- `SERCAP_DIR`: directory for the `sercap.log` and `sercap-last.log` capture
  files (default: current directory).

## License

All scripts and tests are MIT licensed unless otherwise stated. Third-party
components fetched by `setup.sh` (the BATS repositories) are under their own
licenses.

This README document is Copyright (C) 2026 Toradex AG.
