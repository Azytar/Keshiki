# BUG-006: removing a wallpaper named like the select-all row deletes every entry

Status: `CONFIRMED` on upstream baseline `45a1e7e8793e97c0bd79f3953e9bda454ddae329`.

`keshiki-remove` inserts a select-all row whose displayed name is `Todo` in
Spanish or `ALL` in English. It later treats any selected value equal to that
label as the select-all command. A real wallpaper with that name is therefore
indistinguishable and triggers recursive deletion of all desktop/resource
entries. The test copies the original script into a temporary directory,
redirects only its fixed `/tmp` list paths into that directory, and stubs YAD
to select the ordinary `Todo` row.

Run from the repository root:

```sh
bash tests/regressions/BUG-006/reproduce.sh --baseline
bash tests/regressions/BUG-006/reproduce.sh
```

The baseline deletes the unrelated `Keep` wallpaper. The corrected script must
remove only `Todo` in the first case and must correctly process a multi-selection
of indices 1 and 3 while preserving index 2. No host configuration is touched.
