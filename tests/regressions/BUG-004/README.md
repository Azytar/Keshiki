# BUG-004: equal basenames from different directories overwrite an entry

Status: `CONFIRMED` on upstream baseline `45a1e7e8793e97c0bd79f3953e9bda454ddae329`.

`keshiki-add` derives both the desktop filename and resource directory from the
video basename. Two different files named `Scene.mp4` therefore target the
same `desktops/Scene.desktop` entry. The reproduction executes the exact
upstream `keshiki-add` from baseline SHA `45a1e7e8793e97c0bd79f3953e9bda454ddae329`
against two files in isolated directories and counts the generated entries.

Run from the repository root:

```sh
bash tests/regressions/BUG-004/reproduce.sh --baseline
bash tests/regressions/BUG-004/reproduce.sh
```

The first command runs the exact upstream Git object and reproduces one
remaining registration. The second runs the working script and should preserve
two entries after the fix. No host configuration or actual media playback is
involved.
