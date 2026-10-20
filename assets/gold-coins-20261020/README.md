# Gold coin uploads — October 20, 2026

Upload-ready copies of the user's coin art and the two generated egg icons, plus
receipts for the group-owned Roblox images. Contract: `docs/team/GOLD_COINS.md`.

- `prepare_upload.py` — alpha cleanup, 2.5% transparent margin, premultiplied resize to
  at most 1024 px, PNG + raw RGBA output.
- `upload/` — the exact images uploaded. The raw `.rgba` copies Studio read were
  deleted afterwards; `prepare_upload.py` recreates them.
- `upload-receipts.json` — asset ids, sources and where each one is used.

Uploaded through Studio Flow in Edit with `AssetService:CreateEditableImage` and
`CreateAssetAsync` (creator: group 778575811), reading the RGBA from a temporary
localhost file server.
