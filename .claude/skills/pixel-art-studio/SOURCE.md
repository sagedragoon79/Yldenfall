# Source

Vendored from https://github.com/Gamezxz/pixel-art-studio, commit
`f8c246635c4621a6c2b427833149afdc3dc3c719` (2026-07-11), under the MIT License (`LICENSE`
here). Imported 2026-11-05 at Sean's request.

Kept: `SKILL.md`, `references/`, `scripts/`. Left out: `examples/`, `pixel-art/` (the author's
sample builds and their PNG/GIF outputs, one of them fan art of a film character), `docs/`
(the project's web page and its images) and `README.md`.

Changes from the original: `SKILL.md` gained the "In Yldenfall" project note, and its example
`sys.path` now points at this folder instead of the author's home directory.

Review on import: the four scripts use only the Python standard library and Pillow. They read
and write image and JSON files that the caller names, and `study.py` / `pixelpipe.py --study`
write learned palettes and cards inside this folder. Nothing runs a subprocess, opens a
network connection or reads credentials.
