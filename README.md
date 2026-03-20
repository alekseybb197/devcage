# DevCage

The **DevCage** project provides a secure, isolated environment for running the **Qwen‑Code** AI‑assistant inside a Docker container. Qwen‑Code is a terminal‑based programming assistant that can generate code from natural‑language descriptions, automatically fix bugs, perform interactive debugging, and automate common development tasks. The image bundles essential tools (kubectl, helm, yq, jq, node, …) and an entrypoint that records interactive Qwen sessions into convenient logs.

---

## Repository Contents

| File | Description |
|------|-------------|
| `packer.pkr.hcl` | Packer template defining the Docker image build. |
| `variables.pkr.hcl` | Variables for tool versions and feature toggles. |
| `entrypoint.sh` | Wrapper around `qwen` that records a session via `asciinema` and saves a JSON log. |
| `install.sh` | Wrapper script for `packer build`; allows disabling optional components (helm, jq, etc.). |
| `qode` | Script that runs the prepared image in a tmux session, mounting the current project and the `~/.qwen` configuration. |
| `.gitignore` / `.qwenignore` | Files/directories ignored by Git and Qwen‑Code respectively. |
| `README.md` (this file) | Project description in Russian. |
| `README.en.md` | Project description in English. |

---

## Building the Image

```bash
chmod +x install.sh
./install.sh               # build with all options (default)
# example: build without helm and jq
./install.sh --no-helm --no-jq
```

The script runs Packer, which after the build copies the `qode` executable to the directory specified by the `PATH` environment variable, and then:
1. Pulls the base image `debian:13.3-slim` (configurable via `variables.pkr.hcl`).
2. Optionally copies custom CA certificates and `sources.list`.
3. Installs system dependencies.
4. Downloads selected binaries (`kubectl`, `helm`, `yq`, `jq`).
5. Installs Node.js and the `@qwen-code/qwen-code` CLI.
6. Copies `entrypoint.sh` into the image and sets it as the entrypoint.
7. Tags the final image as `qwen-code:<build_version>`.

---

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
* **Plain‑text log** – `${PROJECT}/.qwen/sessions/<timestamp>.log` (result of `asciinema cat`).
* **CAST file** – `${PROJECT}/.qwen/sessions/<timestamp>.cast` (for replaying the session).

---

## Configuration

* Adjust versions and feature flags in `variables.pkr.hcl`.
* Add custom certificates in `ca-certificates/` or a `debian.sources` file – they will be copied during the build (if `copy_certs` / `copy_sources` are enabled).
* Extend `entrypoint.sh` with additional startup steps if needed – the script already runs inside the container as the `agent` user.

---

## Acknowledgments

The development of **DevCage** was performed using **Qwen‑Code** running inside the DevCage environment itself. Embedding Qwen‑Code in the container enabled rapid, iterative creation, debugging, and building of this reproducible development environment for secure AI‑assistant usage.
