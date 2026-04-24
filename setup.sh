#!/bin/bash
#
# Setup Script for JSFinder
#
# Required Tools:
# 1. Basic Requirements:
#    - curl        : Command line tool for transferring data
#    - wget        : Tool for retrieving files using HTTP/HTTPS
#    - git         : Version control system
#    - jq          : Command-line JSON processor
#    - build-essential : Basic build tools (Debian/Ubuntu) / base-devel (Arch)
#
# 2. Main Tools:
#    - golang      : Go programming language (required for other tools)
#    - findomain   : Subdomain enumeration tool
#    - subfinder   : Fast passive subdomain enumeration tool
#    - amass       : Network mapping of attack surfaces
#    - assetfinder : Find domains and subdomains related to a domain
#    - httpx       : Fast and multi-purpose HTTP toolkit
#    - katana      : A next-generation crawling and spidering framework
#    - anew        : Tool for adding new lines to files, skipping duplicates

GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

# Detect package manager
if command -v apt &>/dev/null; then
    PKG_MANAGER="apt"
elif command -v pacman &>/dev/null; then
    PKG_MANAGER="pacman"
else
    printf "${RED}[-] Unsupported system. Only apt (Debian/Ubuntu) and pacman (Arch) based systems are supported.${RESET}\n"
    exit 1
fi

# Detect real user and home (handles sudo) for setting up GO PATH
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
REAL_SHELL=$(basename "$(getent passwd "$REAL_USER" | cut -d: -f7)")

pkg_install() {
    if [ "$PKG_MANAGER" = "apt" ]; then
        sudo apt update &>/dev/null
        sudo apt install -y "$@" &>/dev/null
    else
        sudo pacman -Sy --noconfirm "$@" &>/dev/null
    fi
}

# Check basic tools
check_basic_tools() {
    printf "\n${GREEN}[*] Checking basic requirements... (${PKG_MANAGER} detected)${RESET}\n"
    local basic_tools=(curl wget git jq)
    local missing_tools=()

    for tool in "${basic_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            printf "${RED}[-] $tool is not installed${RESET}\n"
            missing_tools+=("$tool")
        else
            printf "${GREEN}[✓] $tool is already installed${RESET}\n"
        fi
    done

    if [ ${#missing_tools[@]} -ne 0 ]; then
        printf "\n${GREEN}[*] Installing missing tools...${RESET}\n"
        local build_pkg
        [ "$PKG_MANAGER" = "apt" ] && build_pkg="build-essential" || build_pkg="base-devel"
        {
            pkg_install "${missing_tools[@]}" "$build_pkg"
            printf "${GREEN}[+] Basic requirements installed!${RESET}\n"
        } || {
            printf "${RED}[-] Error installing basic requirements. Please try manual installation.${RESET}\n"
            exit 1
        }
    fi

    # Check dig separately — package name differs per distro
    if ! command -v dig &>/dev/null; then
        printf "${RED}[-] dig is not installed${RESET}\n"
        local dig_pkg
        [ "$PKG_MANAGER" = "apt" ] && dig_pkg="dnsutils" || dig_pkg="bind"
        printf "${GREEN}[*] Installing $dig_pkg (provides dig)...${RESET}\n"
        {
            pkg_install "$dig_pkg"
            printf "${GREEN}[✓] $dig_pkg installed!${RESET}\n"
        } || {
            printf "${RED}[-] Error installing $dig_pkg. Try manually: sudo $PKG_MANAGER install $dig_pkg${RESET}\n"
        }
    else
        printf "${GREEN}[✓] dig is already installed${RESET}\n"
    fi
}

persist_go_path() {
    local bash_zsh_block='
# Go environment
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin'

    local fish_block='
# Go environment
set -x GOROOT /usr/local/go
set -x GOPATH $HOME/go
fish_add_path $GOROOT/bin $GOPATH/bin'

    case "$REAL_SHELL" in
        bash)
            local rc="$REAL_HOME/.bashrc"
            if ! grep -q 'GOROOT=/usr/local/go' "$rc" 2>/dev/null; then
                printf "%s\n" "$bash_zsh_block" >> "$rc"
                printf "${GREEN}[✓] Go PATH added to $rc${RESET}\n"
            else
                printf "${GREEN}[✓] Go PATH already configured in $rc${RESET}\n"
            fi
            ;;
        zsh)
            local rc="$REAL_HOME/.zshrc"
            if ! grep -q 'GOROOT=/usr/local/go' "$rc" 2>/dev/null; then
                printf "%s\n" "$bash_zsh_block" >> "$rc"
                printf "${GREEN}[✓] Go PATH added to $rc${RESET}\n"
            else
                printf "${GREEN}[✓] Go PATH already configured in $rc${RESET}\n"
            fi
            ;;
        fish)
            local rc="$REAL_HOME/.config/fish/config.fish"
            mkdir -p "$(dirname "$rc")"
            if ! grep -q 'GOROOT' "$rc" 2>/dev/null; then
                printf "%s\n" "$fish_block" >> "$rc"
                printf "${GREEN}[✓] Go PATH added to $rc${RESET}\n"
            else
                printf "${GREEN}[✓] Go PATH already configured in $rc${RESET}\n"
            fi
            ;;
        *)
            printf "${YELLOW}[!] Unknown shell '$REAL_SHELL'. Add manually to your shell rc:${RESET}\n"
            printf "    export GOROOT=/usr/local/go\n"
            printf "    export GOPATH=\$HOME/go\n"
            printf "    export PATH=\$PATH:\$GOROOT/bin:\$GOPATH/bin\n"
            ;;
    esac
}

GOlang() {
    printf "[*] Installing Golang...\n"
    {
        local sys arch go_info filename expected_sha actual_sha
        sys=$(uname -m)
        case "$sys" in
            x86_64)  arch="amd64" ;;
            i386|i686) arch="386" ;;
            aarch64|arm64) arch="arm64" ;;
            *)
                printf "${RED}[-] Unsupported architecture: $sys${RESET}\n"
                return 1
                ;;
        esac

        go_info=$(curl -s "https://go.dev/dl/?mode=json")
        filename=$(echo "$go_info" | jq -r --arg arch "$arch" \
            '.[0].files[] | select(.os == "linux" and .arch == $arch) | .filename')
        expected_sha=$(echo "$go_info" | jq -r --arg arch "$arch" \
            '.[0].files[] | select(.os == "linux" and .arch == $arch) | .sha256')

        if [ -z "$filename" ] || [ -z "$expected_sha" ]; then
            printf "${RED}[-] Could not fetch latest Golang release info for $arch.${RESET}\n"
            return 1
        fi

        printf "[*] Latest Go version: $(echo "$go_info" | jq -r '.[0].version') ($arch)\n"
        wget "https://go.dev/dl/$filename" -O golang.tar.gz &>/dev/null

        actual_sha=$(sha256sum golang.tar.gz | awk '{print $1}')
        if [ "$actual_sha" != "$expected_sha" ]; then
            printf "${RED}[-] SHA256 mismatch for $filename! Aborting.${RESET}\n"
            rm -f golang.tar.gz
            return 1
        fi
        printf "${GREEN}[✓] SHA256 verified for $filename${RESET}\n"

        sudo tar -C /usr/local -xzf golang.tar.gz
        export GOROOT=/usr/local/go
        export GOPATH=$HOME/go
        export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
        rm golang.tar.gz
        persist_go_path
        printf "${GREEN}[+] Golang Installed!${RESET}\n"
    } || {
        printf "${RED}[-] Error installing Golang. Please try manual installation.${RESET}\n"
        return 1
    }
}

Findomain() {
    printf "[*] Installing Findomain...\n"
    {
        if [ "$PKG_MANAGER" = "pacman" ]; then
            pkg_install findomain
        else
            wget -q https://github.com/findomain/findomain/releases/latest/download/findomain-linux -O findomain-linux
            chmod +x findomain-linux
            sudo mv findomain-linux /usr/local/bin/findomain
        fi
        printf "${GREEN}[+] Findomain Installed!${RESET}\n"
    } || {
        printf "${RED}[-] Error installing Findomain. Please try manual installation.${RESET}\n"
        return 1
    }
}

Subfinder() {
    printf "[*] Installing Subfinder...\n"
    {
        go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest &>/dev/null
        printf "${GREEN}[+] Subfinder Installed!${RESET}\n"
    } || {
        printf "${RED}[-] Error installing Subfinder. Please try manual installation.${RESET}\n"
        return 1
    }
}

Amass() {
    printf "[*] Installing Amass...\n"
    {
        go install github.com/owasp-amass/amass/v4/...@latest &>/dev/null
        printf "${GREEN}[+] Amass Installed!${RESET}\n"
    } || {
        printf "${RED}[-] Error installing Amass. Please try manual installation.${RESET}\n"
        return 1
    }
}

Assetfinder() {
    printf "[*] Installing Assetfinder...\n"
    {
        go install github.com/tomnomnom/assetfinder@latest &>/dev/null
        printf "${GREEN}[+] Assetfinder Installed!${RESET}\n"
    } || {
        printf "${RED}[-] Error installing Assetfinder. Please try manual installation.${RESET}\n"
        return 1
    }
}

Httpx() {
    printf "[*] Installing Httpx...\n"
    {
        go install github.com/projectdiscovery/httpx/cmd/httpx@latest &>/dev/null
        printf "${GREEN}[+] Httpx Installed!${RESET}\n"
    } || {
        printf "${RED}[-] Error installing Httpx. Please try manual installation.${RESET}\n"
        return 1
    }
}

Katana() {
    printf "[*] Installing Katana...\n"
    {
        go install github.com/projectdiscovery/katana/cmd/katana@latest &>/dev/null
        printf "${GREEN}[+] Katana Installed!${RESET}\n"
    } || {
        printf "${RED}[-] Error installing Katana. Please try manual installation.${RESET}\n"
        return 1
    }
}

Anew() {
    printf "[*] Installing Anew...\n"
    {
        go install github.com/tomnomnom/anew@latest &>/dev/null
        printf "${GREEN}[+] Anew Installed!${RESET}\n"
    } || {
        printf "${RED}[-] Error installing Anew. Please try manual installation.${RESET}\n"
        return 1
    }
}

check_basic_tools

printf "\n${GREEN}[*] Checking and installing main tools...${RESET}\n"
hash go 2>/dev/null && printf "${GREEN}[✓] Golang is already installed.${RESET}\n" || GOlang

# Ensure Go binaries are in PATH for this session regardless of whether Go was just installed
export GOROOT=/usr/local/go
export GOPATH="$REAL_HOME/go"
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin

# Persist Go PATH to user's shell rc if not already done
persist_go_path

hash findomain 2>/dev/null && printf "${GREEN}[✓] Findomain is already installed.${RESET}\n" || Findomain
hash subfinder 2>/dev/null && printf "${GREEN}[✓] Subfinder is already installed.${RESET}\n" || Subfinder
hash amass 2>/dev/null && printf "${GREEN}[✓] Amass is already installed.${RESET}\n" || Amass
hash assetfinder 2>/dev/null && printf "${GREEN}[✓] Assetfinder is already installed.${RESET}\n" || Assetfinder
hash httpx 2>/dev/null && printf "${GREEN}[✓] Httpx is already installed.${RESET}\n" || Httpx
hash katana 2>/dev/null && printf "${GREEN}[✓] Katana is already installed.${RESET}\n" || Katana
hash anew 2>/dev/null && printf "${GREEN}[✓] Anew is already installed.${RESET}\n" || Anew

# Make JSFinder.sh executable
chmod +x JSFinder.sh

# Install jsfinder globally via symlink to /usr/local/bin
install_global() {
    local script_path
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/JSFinder.sh"
    local link_path="/usr/local/bin/jsfinder"

    printf "\n${GREEN}[*] Installing jsfinder globally...${RESET}\n"

    if sudo ln -sf "$script_path" "$link_path" 2>/dev/null; then
        printf "${GREEN}[✓] Installed: you can now run 'jsfinder' from anywhere.${RESET}\n"
    else
        printf "${RED}[-] Could not create symlink at $link_path. Try manually:${RESET}\n"
        printf "    sudo ln -sf \"$script_path\" \"$link_path\"\n"
    fi
}

install_global

printf "\n${GREEN}[+] Setup completed!${RESET}\n"
printf "${YELLOW}[!] To apply PATH changes in your current session, run:${RESET}\n"
case "$REAL_SHELL" in
    fish) printf "    source $REAL_HOME/.config/fish/config.fish\n" ;;
    zsh)  printf "    source $REAL_HOME/.zshrc\n" ;;
    *)    printf "    source $REAL_HOME/.bashrc\n" ;;
esac
printf "    ${YELLOW}or open a new terminal.${RESET}\n"
