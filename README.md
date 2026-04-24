# JSFinder

An automation script for JavaScript file enumeration.

![Version](https://img.shields.io/badge/version-1.1-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Description

JSFinder is a comprehensive script designed to automate the process of JavaScript file enumeration. It combines multiple reconnaissance tools to provide thorough scanning capabilities with efficient result processing. All enumeration sources run in parallel, significantly reducing total scan time.

## Tools Used

### Basic Requirements
- curl
- wget
- git
- jq
- dig
- build-essential / base-devel (Arch)

### Main Tools
- Go (golang)     : Required for installing and running various enumeration tools
- findomain      : Used for initial subdomain discovery from multiple sources
- subfinder      : Used for passive subdomain enumeration with high accuracy
- amass          : Used for thorough subdomain mapping and enumeration
- assetfinder    : Used for finding related subdomains and assets
- httpx          : Used for validating live subdomains and web servers
- katana         : Used for crawling websites and discovering JavaScript files
- anew           : Used for removing duplicate findings and maintaining unique results

### Online Services
- crt.sh         : Used for finding subdomains through SSL/TLS certificate logs
- SecurityTrails : Used for historical subdomain data and DNS records (Requires API key: https://securitytrails.com/app/signup)
- WaybackMachine : Used for discovering historical subdomain records
- AbuseIPDB      : Used for additional subdomain discovery through reputation data

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/mahzaraz/JSFinder.git
   cd JSFinder
   ```

2. Run the setup script:
   ```bash
   chmod +x setup.sh
   sudo ./setup.sh
   ```

   The setup script will install all required tools and create a global `jsfinder` command so it can be run from any directory.

   > **Supported systems:** Debian/Ubuntu (`apt`) and Arch-based (`pacman`) distributions.

## Usage

### Basic Command Format
```bash
jsfinder [options] <arguments>
```

### Available Options
| Flag | Description |
|------|-------------|
| `-d, --domain`  | Domain to scan |
| `-l, --list`    | File containing list of domains |
| `-o, --output`  | File to save all subdomain results |
| `-x, --alive`   | File to save live subdomains |
| `-e, --exclude` | Comma-separated subdomain patterns to exclude (e.g. `cdn.*,mail.*`) |
| `-v, --version` | Show version |
| `-h, --help`    | Show help menu |

### Example Usage

1. Scanning a single domain:
   ```bash
   jsfinder -d example.com
   ```

2. Scanning multiple domains sequentially:
   ```bash
   jsfinder -l domains.txt
   ```

3. Saving results to files:
   ```bash
   jsfinder -d example.com -o subdomains.txt -x alive.txt
   ```

> **Note:** In list mode (`-l`), `-o` and `-x` append results from all domains into the specified file. Each domain's JavaScript files are always saved separately as `js-files-{domain}.txt`.

4. Excluding subdomain patterns:
   ```bash
   jsfinder -d example.com --exclude "cdn.*,mail.*,vpn.*"
   ```

## Features

- **Parallel Enumeration**: All 8 subdomain sources run simultaneously, drastically cutting scan time
- **Sequential List Mode**: When using `-l`, domains are scanned one by one to avoid overloading the system
- **Wildcard DNS Detection**: Automatically detects wildcard DNS before enumeration and warns about potential false positives
- **Per-Tool Timeout**: Each tool is given a maximum of 5 minutes; hangs are killed automatically
- **Interrupt Handling**: Ctrl+C cleanly terminates all background processes and removes temp files
- **Logging**: All output is logged with timestamps to `jsfinder-YYYYMMDD-HHMMSS.log`
- **Active Detection**: Identifies live subdomains automatically with httpx
- **JavaScript Discovery**: Automatically finds and extracts JavaScript file URLs via katana
- **Duplicate Handling**: Implements intelligent duplicate removal with anew
- **Error Handling**: Missing tools are skipped with a warning; critical tools abort gracefully

## Output Files

The script generates the following files:
1. `js-files-{domain}.txt` — Discovered JavaScript file URLs (always created, one file per domain)
2. Subdomain list (when using `-o` parameter; appended per domain in list mode)
3. Live subdomain list (when using `-x` parameter; appended per domain in list mode)
4. `jsfinder-YYYYMMDD-HHMMSS.log` — Timestamped log of the full scan

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Mahzaraz - [@mahzaraz](https://github.com/mahzaraz)

<a href="https://www.buymeacoffee.com/mahzaraz" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>
