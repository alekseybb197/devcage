# DevCage 0.0.11

The **DevCage** project provides a secure, isolated environment for running the **Qwen‑Code** AI‑assistant inside a Docker container. Qwen‑Code is a terminal‑based programming assistant that can generate code from natural‑language descriptions, automatically fix bugs, perform interactive debugging, and automate common development tasks. The image bundles essential tools (kubectl, helm, yq, jq, node, …) and an entrypoint that records interactive Qwen sessions into convenient logs.

---

## Repository Contents

| File | Description |
|------|-------------|
| `packer.pkr.hcl` | Packer template defining the Docker image build. |
| `variables.pkr.hcl` | Variables for tool versions and feature toggles. |
| `build.sh` | Builds the Docker image using Packer with optional feature flags. |
| `install.sh` | Installs the `run.sh` script as `/usr/local/bin/qode`. |
| `run.sh` | Launches the prepared image in a tmux session, mounting the project and configuration. |
| `entrypoint.sh` | Wrapper around `qwen` that records a session via `asciinema` and saves a JSON log. |
| `Makefile` | Provides `make build` and `make install` shortcuts for the scripts. |
| `cast-extractor.py` | Extracts prompts from CAST logs. |
| `CONTRIBUTING.md` | Guidelines for contributing to the project. |
| `LICENSE` | License information. |
| `.gitignore` / `.qwenignore` | Files/directories ignored by Git and Qwen‑Code respectively. |
| `README.md` (this file) | Project description in English. |

---

## Building the Image

You can build the Docker image either directly with the `build.sh` script or via the Makefile shortcut:

```bash
chmod +x build.sh
# Direct script usage – pass any of the optional flags defined in build.sh
./build.sh [options]

# Makefile shortcut (recommended) – forwards options via BUILD_OPTS variable
make build               # equivalent to ./build.sh
make build BUILD_OPTS="--no-helm --no-jq"  # example: skip helm and jq
```

The `build.sh` script runs Packer with the computed variables and, upon successful build, retags and finalizes the image. The process includes:
1. Pulling the base image `debian:13.3-slim` (configurable via `variables.pkr.hcl`).
2. Optionally copying custom CA certificates and `sources.list`.
3. Installing system dependencies.
4. Downloading selected binaries (`kubectl`, `helm`, `yq`, `jq`).
5. Installing Node.js and the `@qwen-code/qwen-code` CLI.
6. Adding `entrypoint.sh` as the container entrypoint.
7. Tagging the final image as `qwen-code:<build_version>`.

---

## Build Options

You can customize the image build by adding additional resources to the build context:

* **Custom CA certificates** – Place any `.crt` files in the `ca-certificates/` directory at the repository root. When `copy_certs` is enabled (default), these certificates are copied into the image at `/usr/local/share/ca-certificates` and integrated into the system's trusted store.

* **Custom Debian sources** – Provide a `debian.sources` file in the repository root. When `copy_sources` is enabled (default), this file replaces the default `/etc/apt/sources.list.d/debian.sources` inside the image, allowing you to point to custom mirrors or additional repositories.

These options are controlled by the boolean variables `copy_certs` and `copy_sources` in `variables.pkr.hcl`. Enable or disable them via the corresponding `--no-certs` or `--no-sources` flags when running `install.sh`, or edit the variables file directly.

## Installation

You can install the helper script using the `install.sh` script or via the Makefile shortcut:

```bash
chmod +x install.sh
# Direct script usage – copies run.sh to /usr/local/bin/qode
./install.sh

# Makefile shortcut (recommended) – runs the same script
make install            # equivalent to ./install.sh
```

The `install.sh` script copies `run.sh` to `/usr/local/bin/qode` and makes it executable. The Makefile `install` target runs the same script.

## Preparing for Use

The **qwen‑code** agent running inside the Docker container relies on configuration stored in the `.qwen` directory of the host user profile. It is recommended to install `qwen-code` directly on the host machine and configure `settings.json` for the desired LLM backend connection. Likewise, ensure that `/etc/hosts`, `~/.ssh`, and `~/.kube` are correctly set up, as these files are also mounted into the container.

---

## How to Use

```bash
chmod +x qode
./qode [path/to/project]   # defaults to the current directory
```

You can set the `QODE_VERSION` environment variable to specify the Docker image tag to use (e.g., `QODE_VERSION=1.2.3 ./qode`).

`qode` launches the **Qwen‑Code** agent inside a Docker container, mounting the specified working directory so you can work on the selected project within a fully isolated environment. It:
* Checks for an existing `qwen-code` image and builds it if missing.
* Creates `${PROJECT}/.qwen/sessions` for session logs.
* Mounts the project directory into the container, giving the agent access to the source code.
* Starts the container in a tmux session as the `agent` user.
* Inside the container, `entrypoint.sh` records the interactive Qwen session, saving a JSON log and a human‑readable `.log` file.

### tmux Session Management

| Action | Command |
|--------|---------|
| Detach | `Ctrl‑B D` |
| Re‑attach | `tmux attach -t qwen‑<project>` |
| Kill session | `tmux kill-session -t qwen‑<project>` |
| View container logs | `docker logs <container‑name>` |

---

## Session Logs

* **JSON log** – `${PROJECT}/.qwen/sessions/<timestamp>.json` (raw Qwen output).
* **Prompt extraction JSON** – `${PROJECT}/.qwen/sessions/<timestamp>_prompts.json` (list of prompt strings extracted from the `.cast` file via `cast-extractor.py`).
* **CAST file** – `${PROJECT}/.qwen/sessions/<timestamp>.cast` (for replaying the session).

---

## Configuration

* Adjust versions and feature flags in `variables.pkr.hcl`.
* Add custom certificates in `ca-certificates/` or a `debian.sources` file – they will be copied during the build (if `copy_certs` / `copy_sources` are enabled).
* Extend `entrypoint.sh` with additional startup steps if needed – the script already runs inside the container as the `agent` user.

---

## Acknowledgments

The development of **DevCage** was performed using **Qwen‑Code** running inside the DevCage environment itself. Embedding Qwen‑Code in the container enabled rapid, iterative creation, debugging, and building of this reproducible development environment for secure AI‑assistant usage.
