# 🐚 Bash Scripts

This folder contains various Bash scripts for Linux/macOS environments.

&nbsp;

## 📜 Available Scripts

### `dckrp.sh`
A lightweight CLI wrapper around common Docker Compose commands. Has a _completion_ as well.

#### Features:
- `dckrp` – list all containers (`docker ps -a`)
- `dckrp up` – build and start the Compose project in the current directory
- `dckrp down` – stop and remove containers
- `dckrp logs <container>` – stream logs from a container
- `dckrp clean` – safely clean up unused containers, images, networks
- `dckrp help` – display help menu

#### Usage:
Make the script executable and optionally create an alias:
```bash
chmod +x dckrp.sh
alias dckrp="/path/to/dckrp.sh"
```

#### Completion:
Add to your `.bashrc` following line:
```bash
source /path-to-completion-script/dckrp-completion.sh
```
...and simply reload your `.bashrc` with `source ~/.bashrc`.

&nbsp;

## 📄 License
All scripts in this folder are covered by the root-level [MIT License](../LICENSE).
