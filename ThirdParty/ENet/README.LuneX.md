# ENet vendoring record

- Upstream: `https://github.com/cgutman/enet.git`
- Revision: `aca87840b57f045a1f7f9299e4b1b9b8e2a5e2f1`
- License: MIT; see `LICENSE` in this directory.
- Imported files: portable C sources and public headers required for the static
  Apple-platform build. Windows-only implementation and build-system files are
  intentionally excluded.
- Local modifications: none. LuneX-specific API isolation lives in
  `Sources/LuneXNetworking/CInterop`, outside this directory.

Update this directory only after completing the dependency review and validation
steps in `docs/runtime/dependency-decisions.md`.
