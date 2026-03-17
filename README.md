# Qwen‑Code Docker Image Builder

A reproducible Docker image for **Qwen‑Code** that bundles all required tools
(kubectl, helm, yq, jq, node, …) and provides a convenient entry‑point for
recording interactive Qwen sessions.

## Repository layout

```
.
├── packer.pkr.hcl            # Packer template (HCL) – builds the image
├── variables.pkr.hcl          # All version & feature‑toggle variables
├── entrypoint.sh              # Wrapper that records an asciinema session,
│                               # copies the JSON log and creates a text log.
├── copy_session_log.sh        # (now inlined into entrypoint.sh)
├── build_image.sh             # Helper script that runs `packer build`
│                               # with optional `--no-*` flags.
├── run.sh                     # Starts the built image inside a tmux session.
├── .gitignore                 # Files/dirs ignored by Git.
├── .qwenignore                # Files ignored by Qwen‑Code tooling.
└── README.md                  # ↥ this file
```

### Key files

| File | Purpose |
|------|---------|
| **packer.pkr.hcl** | Defines the Docker build steps using Packer. Conditional provisioners copy custom CA certificates, Debian sources, and optional binaries (kubectl, helm, yq, jq). |
| **variables.pkr.hcl** | Centralised version numbers (`kubectl_version`, `helm_version`, `yq_version`, `jq_version`) and boolean toggles (`copy_certs`, `copy_sources`, `copy_kubectl`, `copy_helm`, `copy_yq`, `copy_jq`). |
| **entrypoint.sh** | Runs `asciinema` to record a Qwen session, then copies the generated `logs.json` to `<session>.json` and converts the `.cast` file to a plain‑text `<session>.log`. |
| **build_image.sh** | Wrapper around `packer build`. Flags `--no-certs`, `--no-sources`, `--no-kubectl`, `--no-helm`, `--no-yq`, `--no-jq` disable the corresponding optional steps. |
| **run.sh** | Launches the built image (`qwen-code:latest`) in a tmux session, mounting the current project and the user’s `~/.qwen` configuration. Handles missing image, creates a temporary Docker run script, and provides tmux shortcuts. |
| **.gitignore** | Prevents committing generated artefacts, caches, and language‑specific files. |
| **.qwenignore** | Tells Qwen‑Code to ignore temporary session artefacts (`.cast`, `.log`, `.json`, tmp directories). |

## Building the image

```bash
# Make sure the helper script is executable (done automatically)
chmod +x build_image.sh

# Build with all optional components (default)
./build_image.sh

# Example: omit helm and jq
./build_image.sh --no-helm --no-jq
```

The command runs Packer, which:
1. Starts from `debian:13.3-slim` (configurable via `base_image`).
2. Optionally copies custom CA certificates and Debian sources.
3. Installs system dependencies.
4. Downloads the requested binaries directly inside the container.
5. Installs nodejs and the Qwen‑Code CLI.
6. Adds the `entrypoint.sh` (with the inlined log‑copy logic) to `/usr/local/bin`.
7. Tags the final image as `qwen-code:latest`.

## Running the container

```bash
chmod +x run.sh
./run.sh   # or: ./run.sh /path/to/your/project
```

`run.sh`:

* Checks that the Docker image exists (triggers `build.sh` if missing).
* Creates a writable `.qwen/sessions` directory inside the project.
* Starts a tmux session that runs the container as the non‑root `agent` user.
* Mounts your project directory and the host’s `~/.qwen` configuration (skills, sessions, tmp, etc.).
* Inside the container `entrypoint.sh` records the Qwen session, saves a JSON log and a human‑readable `.log` file.

### Controlling the container

| Action | Command |
|--------|---------|
| Detach from tmux | `Ctrl‑B D` |
| Re‑attach | `tmux attach -t qwen‑<project‑name>` |
| Kill session | `tmux kill-session -t qwen‑<project‑name>` |
| View container logs (debug) | `docker logs <container‑name>` |
| Remove stopped container | `docker rm <container‑name>` |

## Session logs

* **JSON log**: `<project>/.qwen/sessions/<timestamp>.json` – raw `logs.json` from Qwen.
* **Plain‑text log**: `<project>/.qwen/sessions/<timestamp>.log` – result of `asciinema cat`.
* **Cast file** (binary recording): `<project>/.qwen/sessions/<timestamp>.cast` (kept for possible replay).

## Customisation

* Edit `variables.pkr.hcl` to change base image, tool versions, or toggle features.
* Add your own CA certificates under `ca-certificates/` or a custom `debian.sources` file; the build respects the `copy_certs` and `copy_sources` flags.
* Extend `entrypoint.sh` if you need additional start‑up steps; it is already executable and runs as the `agent` user inside the container.

---

### Thanks

This setup was generated with **Qwen‑Code** and is ready for rapid iteration,
debugging, and reproducible builds of the Qwen‑Code development environment.
