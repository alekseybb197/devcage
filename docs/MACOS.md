# Preparation and Deployment on macOS

This file describes the processes for preparing and deploying the application on the macOS platform.

## Dependencies Requirements

The following dependencies must be installed for the application to work:

- **tmux** — terminal multiplexer
- **Packer** — tool for creating virtual machine images
- **Docker Desktop** — containerization platform
- **qwen-code** — containerized agent (Docker image)

### tmux

Check for tmux:

```bash
whereis tmux
```

Install via Homebrew (if not installed):

```bash
brew install tmux
```

### Packer

Check for Packer:

```bash
whereis packer
```

Install via Homebrew (if not installed):

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/packer
```

### Docker Desktop

Check for Docker:

```bash
whereis docker
```

Installation (if not installed):

1. Install Rosetta 2 (required for Mac with Apple Silicon processor):

```bash
softwareupdate --install-rosetta
```

2. Download Docker Desktop from the official page:
   - https://docs.docker.com/desktop/release-notes/

3. Install Docker Desktop:
   - Open the downloaded `Docker.dmg` file
   - Drag the Docker icon to the Applications folder
   - Launch Docker Desktop by double-clicking

### qwen-code

Installing qwen-code on the host system (macOS):

**Method 1: Quick Install (Recommended)**

```bash
curl -fsSL https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen.sh | bash
```

**Note:** Restart your terminal after installation for environment variable changes to take effect.

**Method 2: Manual Install**

Prerequisites: Node.js version 20 or newer (download from [nodejs.org](https://nodejs.org))

- **Via NPM:**
  ```bash
  npm install -g @qwen-code/qwen-code@latest
  ```

- **Via Homebrew:**
  ```bash
  brew install qwen-code
  ```

**Authentication:**

After installation, run the command and follow the authentication prompts:

```bash
qwen
```

Then execute `/auth` inside Qwen Code, select **Qwen OAuth**, and follow the instructions to verify your account.

**Starting your first session:**

```bash
cd /path/to/your/project
qwen
```

More details: [https://qwenlm.github.io/qwen-code-docs/ru/users/quickstart/](https://qwenlm.github.io/qwen-code-docs/ru/users/quickstart/)

## Application Build

Clone the repository:

```bash
git clone git@github.com:alekseybb197/devcage.git
cd devcage
```

Initialize Packer plugins:

```bash
packer init packer.pkr.hcl
```

This command will install all necessary plugins for Packer.

Check installed plugins:

```bash
packer plugins installed
```

Build the application:

```bash
./build.sh
```

## Troubleshooting

### Building in a Corporate Environment

If building in a closed corporate environment, you need to:

1. **Add Corporate Certificates**

   Create a `ca-certificates` folder and place the necessary certificates in files with the `.crt` extension. These certificates will provide access to internal repository mirrors.

2. **Configure Mirrors for Debian Trixie**

   Edit the `debian.sources` file, specifying internal mirrors in a format similar to the distribution format:

   ```
   Types: deb
   URIs: https://internal-mirror.company.com/debian
   Suites: trixie
   Components: main contrib non-free
   ```

   Replace `https://internal-mirror.company.com/debian` with your internal mirror address.

3. **Configure PyPI Mirror**

   If you have difficulty accessing PyPI, specify the mirror in the `pypy_mirror` variable, for example:

   ```
   pypy_mirror=https://internal-pypi.company.com/simple
   ```

4. **Configure Tool Access in Packer Manifest**

   If there is no access to download necessary tools from the internet, specify paths to corporate resources in the corresponding blocks of the `packer.pkr.hcl` build manifest.

## Build Process

The build occurs in two stages.

### Stage 1: Building the Image with Packer

In the first stage, the image is built using Packer. At this stage, you can configure the required set of tools included in the agent's isolated environment using command-line flags:

| Flag | Description |
|------|----------|
| `--no-certs` | Disable copying custom CA certificates |
| `--no-sources` | Disable copying custom Debian sources |
| `--no-kubectl` | Skip downloading kubectl inside the image |
| `--no-helm` | Skip downloading helm |
| `--no-yq` | Skip downloading yq |
| `--no-jq` | Skip downloading jq |
| `--no-ansible` | Skip installing Ansible |
| `--no-plantuml` | Skip installing PlantUML and dependencies |
| `--no-go` | Skip installing Go |

Example build with disabled tools:

```bash
./build.sh --no-kubectl --no-helm --no-ansible
```

By default, the script automatically detects the presence of `debian.sources` file and `ca-certificates` folder, and disables the corresponding options if they are missing.

### Stage 2: Image Optimization with Docker

In the second stage, Docker is used for final image optimization:

- **Layer squashing** — all image layers are combined into one base layer
- **Removing redundant data** — all intermediate data hidden in inactive layers is removed
- **Creating a clean image** — a final optimized image with minimal size is formed

This stage is executed automatically after a successful Packer build and does not require additional intervention.

## Build Result

As a result of the build, a `qwen-code` image is created with a tag corresponding to the release version.

Check the created image:

```bash
docker images -a | grep qwen-code
```

Example output:

```
qwen-code:0.0.11    86084c69e30a    3.34GB    780MB
```

Where:
- **3.34GB** — image size before optimization (after Packer stage)
- **780MB** — final optimized image size (after Docker stage)

## Application Installation

Installation is performed with the command:

```bash
./install.sh
```

During installation, a script is created to launch the containerized agent with strictly defined data passed from the host system.

### Mounted Volumes

The following directories and files are mounted when the container is launched:

| Host Path | Container Path | Mode | Description |
|---------------|-------------------|-------|----------|
| `${PROJECT_PATH}` | `/workspace/${PROJECT_NAME}` | rw | Project working directory |
| `${HOME}/.qwen` | `/home/agent/.qwen` | ro | Qwen configuration (read-only) |
| `${HOME}/.qwen/agents` | `/home/agent/.qwen/agents` | rw | Agent data |
| `${HOME}/.qwen/debug` | `/home/agent/.qwen/debug` | rw | Debug information |
| `${HOME}/.qwen/projects` | `/home/agent/.qwen/projects` | rw | Projects |
| `${HOME}/.qwen/skills` | `/home/agent/.qwen/skills` | rw | Skills |
| `${HOME}/.qwen/tmp` | `/home/agent/.qwen/tmp` | rw | Temporary files |
| `${HOME}/.qwen/todos` | `/home/agent/.qwen/todos` | rw | Task list |
| `${HOME}/.ssh` | `/home/agent/.ssh` | ro | SSH keys (read-only) |
| `${HOME}/.kube` | `/home/agent/.kube` | ro | Kubernetes configuration (read-only) |
| `/etc/hosts` | `/etc/hosts` | ro | Hosts file (read-only) |

**Mode designations:**
- **rw** — read and write
- **ro** — read-only

## Agent Launch

### Configuring qwen-code on the Host

Before launching the containerized agent, you need to configure qwen-code on the host system:

1. **Launch qwen-code on the host:**

   ```bash
   qwen
   ```

2. **Configure access to the LLM backend:**

   - Specify the access token
   - Select the model to work with
   - Verify the configuration works

3. **Configure additional agent parameters**

   During an interactive session on the host, you can configure various agent working parameters.

   Available commands: [https://qwenlm.github.io/qwen-code-docs/ru/users/features/commands/](https://qwenlm.github.io/qwen-code-docs/ru/users/features/commands/)

After completing the configuration, you can proceed to launch the containerized agent.

### Launching the Containerized Agent

The application is launched with the command:

```bash
qode <path_to_project_folder>
```

This command performs the following:

1. **Container creation** — based on the previously built `qwen-code` image
2. **Data mounting** — all necessary data is mounted into the container (as described in the [Mounted Volumes](#mounted-volumes) section)
3. **Agent launch** — the qwen agent is launched inside the container

### Working in a tmux Session

**Important note:** The container launch is wrapped in a `tmux` session. This allows you to:

- Deploy work on remote hosts
- Not worry about the terminal session closing due to connection interference or disconnection
- Resume work at any time

**Managing the tmux session:**

| Action | Command |
|----------|---------|
| Detach from session | `Ctrl+B`, then `D` |
| Attach to session | `tmux attach -t <SESSION_NAME>` |
| Kill session | `tmux kill-session -t <SESSION_NAME>` |

Where `SESSION_NAME` has the format `qwen-<project_name>`.

### Session Management

The current session ID is stored in the file:

```
<project_path>/.qwen/session.id
```

At each launch, the agent automatically resumes the session specified in this file. This allows you to continue working from where you left off.

**Starting a new session:**

If you need to start a fresh session in the project, simply delete the `session.id` file:

```bash
rm <project_path>/.qwen/session.id
```

On the next launch, a new session will be created automatically.

### Work Logs

Agent work logs are saved to the directory:

```
~/.qwen/debug/
```

And also to the session file:

```
<project_path>/.qwen/sessions/
```

### Session Log Format

After each session completes, the session log is automatically copied to the project's session directory with a timestamped filename:

```
<project_path>/.qwen/sessions/YYYYMMDD-HHMMSS-{SESSION_ID}.jsonl
```

Where:
- **`YYYYMMDD-HHMMSS`** — Date and time prefix (e.g., `20260325-143022`)
- **`{SESSION_ID}`** — Unique session identifier
- **`.jsonl`** — JSON Lines format (one JSON object per line)

Example filename:

```
20260325-143022-abc12345-6789-def0.jsonl
```

This format allows you to:
- Track session history chronologically
- Identify sessions by date/time and ID
- Parse logs programmatically (JSONL format)

---

## Conclusion

You are now ready to work with DevCage on macOS.

**Happy coding and productive development!** 🚀
