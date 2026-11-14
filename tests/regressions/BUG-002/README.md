# BUG-002: wallpaper paths with spaces are split before xwinwrap/mpv

Status: `CONFIRMED` on upstream baseline `45a1e7e8793e97c0bd79f3953e9bda454ddae329`.

`keshiki-start` assembles `mpv_args` as a scalar string and expands it
unquoted in the `xwinwrap` command. This loses the original argument boundary:
`My Fondo.mp4` arrives as two arguments. The test runs the original launcher
with disposable stubs for `xwinwrap`, `keshiki-cli`, `sleep`, and `pidof`;
the `xwinwrap` stub records each argument as a NUL-terminated field. It never
launches a real wallpaper, mpv, or host process manager.

Run from the repository root:

```sh
bash tests/regressions/BUG-002/reproduce.sh --baseline
bash tests/regressions/BUG-002/reproduce.sh
```

The baseline command executes the exact upstream `keshiki-start` and fails on
the first spaced filename because the final argument received by the mpv stub
is not the full path. The corrected script passes. Apostrophe, dollar sign,
Unicode, leading-hyphen filenames, and a YouTube URL are also checked; the
baseline retained the special characters in the direct local-file experiment.
