# BUG-003: generated desktop entry does not preserve an Exec argument

Status: `SPEC VIOLATION` on upstream baseline `45a1e7e8793e97c0bd79f3953e9bda454ddae329`.

`keshiki-add` writes `Exec=${HERE}/keshiki-start '${file}'`. The generated
desktop entry is executed by a Desktop Entry parser, not by a shell. This test
uses the real `keshiki-add` generator on placeholder files, validates every
generated entry with `desktop-file-validate`, launches one entry through
`gtk-launch` into a capture stub, and checks CLI listing/selection with a
`keshiki-start` capture stub. It does not start Keshiki or a video player.

Run from the repository root:

```sh
bash tests/regressions/BUG-003/reproduce.sh --baseline
bash tests/regressions/BUG-003/reproduce.sh
```

The first command uses the upstream `keshiki-add` and `keshiki-cli` from the
recorded SHA. Its first generated `Exec=` contains single quotes outside a
valid Desktop Entry quoted argument, and the validator rejects the entry. The
working version must validate entries for spaces, parentheses, quotes,
backslashes, percent signs, dollar signs, backticks, Unicode, pipes, and
leading hyphens, then pass the full spaced path as one runtime argument. The
CLI subtest verifies that `-l` followed by `-s 1` preserves each path as one
argument.
