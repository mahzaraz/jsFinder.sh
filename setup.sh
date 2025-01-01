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
#    - build-essential : Basic build tools
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

# Color definitions for output
GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

# Check basic tools
check_basic_tools() {
    printf "\n${GREEN}[*] Checking basic requirements...${RESET}\n"
    basic_tools=(curl wget git jq)
    missing_tools=()
    
    for tool in ${basic_tools[@]}; do
        if ! command -v $tool &>/dev/null; then
            printf "${RED}[-] $tool is not installed${RESET}\n"
            missing_tools+=($tool)
        else
            printf "${GREEN}[✓] $tool is already installed${RESET}\n"
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        printf "\n${GREEN}[*] Installing missing tools...${RESET}\n"
        {
            sudo apt update &>/dev/null
            sudo apt install -y ${missing_tools[@]} build-essential &>/dev/null
            printf "${GREEN}[+] Basic requirements installed!${RESET}\n"
        } || {
            printf "${RED}[-] Error installing basic requirements. Please try manual installation.${RESET}\n"
            exit 1
        }
    fi
}

GOlang() {
    printf "[*] Installing Golang...\n"
    {
        sys=$(uname -m)
        [ $sys == "x86_64" ] && wget https://go.dev/dl/go1.21.4.linux-amd64.tar.gz -O golang.tar.gz &>/dev/null || wget https://go.dev/dl/go1.21.4.linux-386.tar.gz -O golang.tar.gz &>/dev/null
        sudo tar -C /usr/local -xzf golang.tar.gz
        export GOROOT=/usr/local/go
        export GOPATH=$HOME/go
        export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
        echo "[!] Add The Following Lines To Your ~/.${SHELL##*/}rc file:"
        echo 'export GOROOT=/usr/local/go'
        echo 'export GOPATH=$HOME/go'
        echo 'export PATH=$PATH:$GOROOT/bin:$GOPATH/bin'
        rm golang.tar.gz
        printf "${GREEN}[+] Golang Installed!${RESET}\n"
    } || {
        printf "${RED}[-] Error installing Golang. Please try manual installation.${RESET}\n"
        return 1
    }
}

Findomain() {
    printf "[*] Installing Findomain...\n"
    {
        wget https://github.com/findomain/findomain/releases/latest/download/findomain-linux &>/dev/null
        chmod +x findomain-linux
        sudo mv findomain-linux /usr/local/bin/findomain
        printf "${GREEN}[+] Findomain Installed!${RESET}\n"
    } || {
        printf "${RED}[-] Error installing Findomain. Please try manual installation.${RESET}\n"
        return 1
    }
}

Subfinder() {
    printf "[*] Installing Subfinder...\n"
    {
        go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest &>/dev/null
        printf "${GREEN}[+] Subfinder Installed!${RESET}\n"
    } || {
        printf "${RED}[-] Error installing Subfinder. Please try manual installation.${RESET}\n"
        return 1
    }
}

Amass() {
    printf "[*] Installing Amass...\n"
    {
        go install -v github.com/owasp-amass/amass/v4/...@master &>/dev/null
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
        go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest &>/dev/null
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
        go install -v github.com/tomnomnom/anew@latest &>/dev/null
        printf "${GREEN}[+] Anew Installed!${RESET}\n"
    } || {
        printf "${RED}[-] Error installing Anew. Please try manual installation.${RESET}\n"
        return 1
    }
}

# First check basic tools
check_basic_tools

# Check and install main tools
printf "\n${GREEN}[*] Checking and installing main tools...${RESET}\n"
hash go 2>/dev/null && printf "${GREEN}[✓] Golang is already installed.${RESET}\n" || GOlang
hash findomain 2>/dev/null && printf "${GREEN}[✓] Findomain is already installed.${RESET}\n" || Findomain
hash subfinder 2>/dev/null && printf "${GREEN}[✓] Subfinder is already installed.${RESET}\n" || Subfinder
hash amass 2>/dev/null && printf "${GREEN}[✓] Amass is already installed.${RESET}\n" || Amass
hash assetfinder 2>/dev/null && printf "${GREEN}[✓] Assetfinder is already installed.${RESET}\n" || Assetfinder
hash httpx 2>/dev/null && printf "${GREEN}[✓] Httpx is already installed.${RESET}\n" || Httpx
hash katana 2>/dev/null && printf "${GREEN}[✓] Katana is already installed.${RESET}\n" || Katana
hash anew 2>/dev/null && printf "${GREEN}[✓] Anew is already installed.${RESET}\n" || Anew

# Make JSFinder.sh executable
chmod +x JSFinder.sh

printf "\n${GREEN}[+] Setup completed!${RESET}\n" 