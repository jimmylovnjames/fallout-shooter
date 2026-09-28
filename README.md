# WASTELAND (working title)

Top-down open-world post-apocalyptic RPG shooter for Android, built in Godot 4.7 — an original-IP
homage to the open-world wasteland RPG genre.

- **Play a build:** grab the APK from the latest [Release](../../releases) (phase builds) or from
  the Actions run artifacts (every push). Allow installs from unknown sources, open the APK.
- **Design:** [`docs/DESIGN.md`](docs/DESIGN.md) · **Roadmap:** [`docs/ROADMAP.md`](docs/ROADMAP.md) ·
  **Decisions:** [`docs/DECISIONS.md`](docs/DECISIONS.md) · **Perf:** [`docs/PERF.md`](docs/PERF.md)
- **Build locally (Linux):**
  ```bash
  tools/setup_toolchain.sh --with-render
  tools/ci.sh            # lint, tests, signed APK in build/, screenshot + benchmark
  ```
- **Contributing / conventions:** [`CLAUDE.md`](CLAUDE.md)
