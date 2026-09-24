# Preserved scripts outside runtime sync

`studio-scripts/` holds every exported script outside the active gameplay and test containers: old recovery copies, material/import libraries, VFX-pack code, Photobooth helpers and the disabled style preview. Their original paths, classes, properties and hashes are in `docs/migration/source-manifest.json`. Repeated identical Studio paths receive numeric filename suffixes so no source is lost.

These files are not in either Rojo mapping. They remain in their original Studio locations; this folder is a reference copy, not an instruction to enable or restore them. Some scripts belong to third-party tools and retain their original comments. Do not represent third-party code as original game code.

`previous-local/` preserves the five older local source entries that differed from or were absent in the current Studio export. The active migration deliberately uses current Studio bytes. The differences and decisions are recorded in `docs/migration/previous-local-differences.json`.
