# JSFinder

An automation script for JavaScript file enumeration.

![Version](https://img.shields.io/badge/version-1.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Description

JSFinder is a comprehensive script designed to automate the process of JavaScript file enumeration. It combines multiple reconnaissance tools to provide thorough scanning capabilities with efficient result processing.

## Tools Used

### Basic Requirements
- curl
- wget
- git 
- jq
- build-essential

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
- crt.sh        : Used for finding subdomains through SSL/TLS certificate logs
- SecurityTrails : Used for historical subdomain data and DNS records (Requires API key: https://securitytrails.com/app/signup)
- WaybackMachine : Used for discovering historical subdomain records
- AbuseIPDB     : Used for additional subdomain discovery through reputation data

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

## Usage

### Basic Command Format
```bash
./JSFinder.sh [options] <arguments>
```

### Available Options
- `-d, --domain`    : Domain to scan
- `-l, --list`      : File containing list of domains
- `-o, --output`    : File to save subdomain results
- `-x, --alive`     : File to save active subdomains
- `-t, --thread`    : Number of threads (default: 40)
- `-h, --help`      : Show help menu

### Example Usage

1. Scanning a single domain:
   ```bash
   ./JSFinder.sh -d example.com
   ```

2. Scanning multiple domains:
   ```bash
   ./JSFinder.sh -l domains.txt
   ```

3. Saving results to files:
   ```bash
   ./JSFinder.sh -d example.com -o subdomains.txt -x alive.txt
   ```

## Features

- **Comprehensive Scanning**: Utilizes multiple sources for thorough subdomain discovery
- **Active Detection**: Identifies live subdomains automatically
- **JavaScript Discovery**: Automatically finds and extracts JavaScript file URLs
- **Duplicate Handling**: Implements intelligent duplicate removal
- **User-Friendly**: Features colored and descriptive output
- **Error Handling**: Provides automatic error notification and suggestions

## Output Files

The script generates the following files:
1. List of subdomains (when using `-o` parameter)
2. List of active subdomains (when using `-x` parameter)
3. List of JavaScript files (`js-files-{domain}.txt`)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Mahzaraz - [@mahzaraz](https://github.com/mahzaraz)
