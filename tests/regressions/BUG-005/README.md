# BUG-005: selecting a path that prefixes the saved path does not update restore state

Status: `CONFIRMED` on upstream baseline `45a1e7e8793e97c0bd79f3953e9bda454ddae329`.

`keshiki-start` uses `grep -qF "$1" "$last_wall"` to decide whether the
selection changed. This is a substring check, so selecting `video.mp4` while
`video.mp4.bak` is saved leaves the latter as the restore target. The test uses
two disposable files, a private HOME, and stubs for the process launcher.

Run from the repository root:

```sh
bash tests/regressions/BUG-005/reproduce.sh --baseline
bash tests/regressions/BUG-005/reproduce.sh
```

The baseline command must fail by observing the stale saved path. The working
script must save the exact path selected. No wallpaper, IPC socket, or host
process is launched.
