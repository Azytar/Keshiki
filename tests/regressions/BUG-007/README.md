# BUG-007: remove dialog arguments split wallpaper names containing spaces

Status: `CONFIRMED` on upstream baseline `45a1e7e8793e97c0bd79f3953e9bda454ddae329`.

`keshiki-remove` passes `$(cat "$final_list")` unquoted to YAD. Shell word
splitting turns a single row value such as `My Wallpaper` into two arguments.
The test captures YAD's exact `argv` with a stub using one wallpaper whose
desktop filename contains a space.

Run from the repository root:

```sh
bash tests/regressions/BUG-007/reproduce.sh --baseline
bash tests/regressions/BUG-007/reproduce.sh
```

The baseline must not contain one argument equal to `My Wallpaper`; the
corrected version must preserve it as one argument. No GUI or host data is
modified.
