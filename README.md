# DevCage 0.0.17

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
| `entrypoint.sh` | Wrapper around `qwen` that resumes session and copies session logs. |
| `Makefile` | Provides `make build` and `make install` shortcuts for the scripts. |
| `CONTRIBUTING.md` | Guidelines for contributing to the project. |
| `LICENSE` | License information. |
| `.gitignore` / `.qwenignore` | Files/directories ignored by Git and Qwen‑Code respectively. |
| `README.md` (this file) | Project description in English. |

---

## Documentation

For detailed instructions on building and installing DevCage, refer to the platform-specific guides:

- **[Linux Installation Guide](docs/LINUX.md)** – Complete instructions for building and running DevCage on Linux systems.
- **[macOS Installation Guide](docs/MACOS.md)** – Complete instructions for building and running DevCage on macOS systems.

---

## Acknowledgments

The development of **DevCage** was performed using **Qwen‑Code** running inside the DevCage environment itself. Embedding Qwen‑Code in the container enabled rapid, iterative creation, debugging, and building of this reproducible development environment for secure AI‑assistant usage.
