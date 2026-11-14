# BUG-001: desktop entry uses a different installation path

Status: `CONFIRMED` on upstream baseline `45a1e7e8793e97c0bd79f3953e9bda454ddae329`.

`install.sh` installs files under `/opt/keshiki`, but its generated `Exec=` and
`Icon=` fields name `/opt/Keshiki`. On a case-sensitive filesystem, the desktop
launcher therefore points to a nonexistent executable. The test builds a
private installation tree, generates the desktop entry from the installer
values, validates its syntax, and asserts that `Exec=` resolves to the installed
executable.

Run from the repository root:

```sh
bash tests/regressions/BUG-001/reproduce.sh --baseline
bash tests/regressions/BUG-001/reproduce.sh
```

The first command reads `install.sh` directly from the recorded upstream SHA and
fails with `Exec target differs from INSTALL_DIR`. The second uses the working
script and passes;
`desktop-file-validate` accepts the syntax but cannot validate target existence.
The test does not run `install.sh` as root or modify `/opt`.
