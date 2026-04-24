#!/bin/bash
#
# JavaScript File Discovery Script
#
# This script performs subdomain enumeration using various tools and techniques,
# then discovers JavaScript files from live subdomains using katana.
# The script can save both subdomain lists and active subdomain lists optionally,
# while always saving discovered JavaScript files.
#
# Tools used:
#   * findomain    - Subdomain enumeration
#   * subfinder    - Subdomain enumeration
#   * amass        - Subdomain enumeration
#   * assetfinder  - Subdomain enumeration
#   * httpx        - Live subdomain detection
#   * securitytrails - Subdomain enumeration via API
#   * katana       - JavaScript file discovery

VERSION="1.1"
PRG=${0##*/}
LOG_FILE="jsfinder-$(date +%Y%m%d-%H%M%S).log"
TOOL_TIMEOUT=300  # Max seconds allowed per tool (default: 5 minutes)


RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"


declare -a ALL_PIDS=()

log() {
    local level="$1"
    local msg="$2"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    case "$level" in
        INFO)  echo -e "${GREEN}[+]${RESET} $msg" ;;
        WARN)  echo -e "${YELLOW}[!]${RESET} $msg" ;;
        ERROR) echo -e "${RED}[-]${RESET} $msg" ;;
        STEP)  echo -e "${BLUE}[*]${RESET} $msg" ;;
        *)     echo -e "$msg" ;;
    esac
    echo "[$ts] [$level] $msg" >> "$LOG_FILE"
}

handle_interrupt() {
    echo ""
    log WARN "Interrupt received. Terminating all background processes..."
    for pid in "${ALL_PIDS[@]}"; do
        pkill -TERM -P "$pid" 2>/dev/null
        kill -TERM "$pid" 2>/dev/null
    done
    sleep 1
    for pid in "${ALL_PIDS[@]}"; do
        kill -KILL "$pid" 2>/dev/null
    done
    wait 2>/dev/null
    # Clean up all possible temp files left by any domain
    rm -f tmp-wayback-* tmp-crt-* tmp-abuseipdb-* tmp-securitytrails-* \
          tmp-findomain-* tmp-subfinder-* tmp-amass-* tmp-assetfinder-* \
          tmp-all-*.txt tmp-alive-*.txt 2>/dev/null
    log WARN "Cleanup complete. Exiting."
    exit 130
}

trap handle_interrupt INT TERM

Usage() {
    echo "Usage:"
    echo "    -d, --domain      - Target domain to scan"
    echo "    -l, --list        - File containing list of domains"
    echo "    -o, --output      - Save all subdomains to output file"
    echo "    -x, --alive       - Save live subdomains to output file"
    echo "    -e, --exclude     - Comma-separated subdomain patterns to exclude (e.g. cdn.*,mail.*)"
    echo "    -v, --version     - Display version"
    echo "    -h, --help        - Display this help menu"
    echo ""
    echo "Examples:"
    echo "    $PRG -d example.com"
    echo "    $PRG -l domains.txt"
    echo "    $PRG -d example.com -o results.txt -x alive.txt"
    echo "    $PRG -d example.com --exclude \"cdn.*,mail.*,vpn.*\""
    exit 1
}

apply_exclude_filter() {
    local file="$1"
    local grep_pattern=""
    local p

    IFS=',' read -ra patterns <<< "$exclude"
    for p in "${patterns[@]}"; do
        p=$(printf '%s' "$p" | sed 's/\./\\./g; s/\*/\.\*/g')
        grep_pattern="${grep_pattern}|${p}"
    done
    grep_pattern="${grep_pattern:1}"

    grep -vE "$grep_pattern" "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    log INFO "Exclude filter applied: $exclude"
}

validate_domain() {
    local d="$1"
    if [[ ! "$d" =~ ^[a-zA-Z0-9_]([a-zA-Z0-9_-]{0,61}[a-zA-Z0-9_])?(\.[a-zA-Z0-9_]([a-zA-Z0-9_-]{0,61}[a-zA-Z0-9_])?)*\.[a-zA-Z]{2,}$ ]]; then
        log ERROR "Invalid domain format: '$d'"
        return 1
    fi
}

check_tool() {
    if ! command -v "$1" &>/dev/null; then
        log WARN "'$1' not found, skipping."
        return 1
    fi
    return 0
}

check_wildcard() {
    if ! command -v dig &>/dev/null; then
        log WARN "dig not found, skipping wildcard DNS check."
        return
    fi
    local random_sub="noexist-$(tr -dc 'a-z0-9' </dev/urandom | head -c 10).$domain"
    log STEP "Checking for wildcard DNS on '$domain'..."
    if dig +short "$random_sub" 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        log WARN "Wildcard DNS detected for '$domain' — all subdomains resolve, results may contain false positives"
    else
        log INFO "No wildcard DNS detected for '$domain'"
    fi
}

wayback() {
    local out_file="tmp-wayback-$domain"
    if timeout "$TOOL_TIMEOUT" curl -sk \
        "http://web.archive.org/cdx/search/cdx?url=*.$domain&output=txt&fl=original&collapse=urlkey&page=" | \
        awk -F/ '{gsub(/:.*/, "", $3); print $3}' | sort -u > "$out_file"; then
        log STEP "WayBackMachine: $(wc -l < "$out_file") subdomains"
    else
        log ERROR "WayBackMachine query failed or timed out for '$domain'"
        touch "$out_file"
    fi
}

crt() {
    local out_file="tmp-crt-$domain"
    if timeout "$TOOL_TIMEOUT" curl -sk "https://crt.sh/?q=%.$domain&output=json" | \
        tr ',' '\n' | awk -F'"' '/name_value/ {gsub(/\*\./, "", $4); gsub(/\\n/,"\n",$4); print $4}' | \
        sort -u > "$out_file"; then
        log STEP "crt.sh: $(wc -l < "$out_file") subdomains"
    else
        log ERROR "crt.sh query failed or timed out for '$domain'"
        touch "$out_file"
    fi
}

abuseipdb() {
    local out_file="tmp-abuseipdb-$domain"
    if timeout "$TOOL_TIMEOUT" curl -s "https://www.abuseipdb.com/whois/$domain" \
        -H "user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" | \
        grep -oP '(?<=<li>)[^<]+' | grep -v "^[[:space:]]*$" | sed "s/$/.$domain/" | sort -u > "$out_file"; then
        log STEP "AbuseIPDB: $(wc -l < "$out_file") subdomains"
    else
        log ERROR "AbuseIPDB query failed or timed out for '$domain'"
        touch "$out_file"
    fi
}

securitytrails() {
    local out_file="tmp-securitytrails-$domain"
    local ST_API_KEY="YOUR_API_KEY_HERE"

    if [ "$ST_API_KEY" = "YOUR_API_KEY_HERE" ]; then
        log WARN "SecurityTrails: API key not configured, skipping."
        touch "$out_file"
        return
    fi

    local response
    response=$(timeout "$TOOL_TIMEOUT" curl -s \
        "https://api.securitytrails.com/v1/domain/$domain/subdomains" \
        -H "APIKEY: $ST_API_KEY" \
        -H "Accept: application/json")

    if echo "$response" | jq -e '.subdomains' >/dev/null 2>&1; then
        echo "$response" | jq -r '.subdomains[]' | sed "s/$/.$domain/" | sort -u > "$out_file"
        log STEP "SecurityTrails: $(wc -l < "$out_file") subdomains"
    else
        local err_msg
        err_msg=$(echo "$response" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Unknown error")
        log ERROR "SecurityTrails API error: $err_msg"
        touch "$out_file"
    fi
}

Findomain() {
    local out_file="tmp-findomain-$domain"
    if check_tool findomain; then
        timeout "$TOOL_TIMEOUT" findomain -t "$domain" -u "$out_file" &>/dev/null
        log STEP "Findomain: $(wc -l < "$out_file") subdomains"
    else
        touch "$out_file"
    fi
}

Subfinder() {
    local out_file="tmp-subfinder-$domain"
    if check_tool subfinder; then
        timeout "$TOOL_TIMEOUT" subfinder -all -silent -d "$domain" 1> "$out_file" 2>/dev/null
        log STEP "SubFinder: $(wc -l < "$out_file") subdomains"
    else
        touch "$out_file"
    fi
}

Amass() {
    local out_file="tmp-amass-$domain"
    if check_tool amass; then
        timeout "$TOOL_TIMEOUT" amass enum -passive -norecursive -noalts -d "$domain" \
            1> "$out_file" 2>/dev/null
        log STEP "Amass: $(wc -l < "$out_file") subdomains"
    else
        touch "$out_file"
    fi
}

Assetfinder() {
    local out_file="tmp-assetfinder-$domain"
    if check_tool assetfinder; then
        timeout "$TOOL_TIMEOUT" assetfinder --subs-only "$domain" > "$out_file"
        log STEP "AssetFinder: $(wc -l < "$out_file") subdomains"
    else
        touch "$out_file"
    fi
}

run_enumeration() {
    local pids=()
    log INFO "Starting parallel subdomain enumeration for: $domain"

    wayback &        pids+=($!); ALL_PIDS+=($!)
    crt &            pids+=($!); ALL_PIDS+=($!)
    abuseipdb &      pids+=($!); ALL_PIDS+=($!)
    securitytrails & pids+=($!); ALL_PIDS+=($!)
    Findomain &      pids+=($!); ALL_PIDS+=($!)
    Subfinder &      pids+=($!); ALL_PIDS+=($!)
    Amass &          pids+=($!); ALL_PIDS+=($!)
    Assetfinder &    pids+=($!); ALL_PIDS+=($!)

    log STEP "Waiting for all enumeration tools to complete (timeout: ${TOOL_TIMEOUT}s each)..."
    local failed=0
    for pid in "${pids[@]}"; do
        wait "$pid" || ((failed++))
    done

    if [ "$failed" -gt 0 ]; then
        log WARN "$failed enumeration task(s) encountered errors or timed out"
    fi
}

cleanup() {
    rm -f "tmp-wayback-$domain" "tmp-crt-$domain" "tmp-abuseipdb-$domain" \
          "tmp-securitytrails-$domain" "tmp-findomain-$domain" "tmp-subfinder-$domain" \
          "tmp-amass-$domain" "tmp-assetfinder-$domain" \
          "tmp-all-$domain.txt" "tmp-alive-$domain.txt"
}

PROCESS_RESULTS() {
    if ! check_tool anew; then
        log ERROR "anew is required but not found. Aborting."
        cleanup
        return 1
    fi

    log INFO "Processing results with anew..."
    local all_file="tmp-all-$domain.txt"

    for file in "tmp-wayback-$domain" "tmp-crt-$domain" "tmp-abuseipdb-$domain" \
                "tmp-securitytrails-$domain" "tmp-findomain-$domain" "tmp-subfinder-$domain" \
                "tmp-amass-$domain" "tmp-assetfinder-$domain"; do
        [ -f "$file" ] && cat "$file" | anew "$all_file" >/dev/null
    done

    if [ "$exclude" != "False" ]; then
        apply_exclude_filter "$all_file"
    fi

    local result
    result=$(wc -l < "$all_file")
    log INFO "Total unique subdomains: $result"

    if [ "$out" != "False" ]; then
        cat "$all_file" >> "$out"
        log INFO "All subdomains appended to: $out"
    fi

    if ! check_tool httpx; then
        log ERROR "httpx is required but not found. Aborting."
        cleanup
        return 1
    fi

    log INFO "Checking for live subdomains with httpx..."
    local alive_file="tmp-alive-$domain.txt"
    cat "$all_file" | httpx -silent | anew "$alive_file" >/dev/null
    local alive_count
    alive_count=$(wc -l < "$alive_file")
    log INFO "Live subdomains found: $alive_count"

    if [ "$alive" != "False" ]; then
        cat "$alive_file" >> "$alive"
        log INFO "Live subdomains appended to: $alive"
    fi

    if ! check_tool katana; then
        log ERROR "katana is required but not found. Aborting JS scan."
        cleanup
        return 1
    fi

    log INFO "Running katana scan for JavaScript files..."
    local js_file="js-files-$domain.txt"
    katana -list "$alive_file" -d 5 -jc | grep -E '\.(js|jsp|php|json)(\?[^"]*)?$' | anew "$js_file" >/dev/null
    local js_count
    js_count=$(wc -l < "$js_file")
    log INFO "JavaScript files found: $js_count — saved to: $js_file"

    cleanup
    log INFO "Scan complete for $domain. Log saved to: $LOG_FILE"
}

scan_domain() {
    local d="$1"
    domain="$d"
    log INFO "=== Scanning domain: $domain ==="
    check_wildcard
    run_enumeration
    PROCESS_RESULTS || { log ERROR "Scan failed for $domain. Skipping."; return 1; }
    ALL_PIDS=()
}

LIST() {
    if [ ! -f "$hosts" ]; then
        log ERROR "Domain list file not found: $hosts"
        exit 1
    fi

    while read -r d; do
        [ -z "$d" ] && continue
        [[ "$d" == \#* ]] && continue
        validate_domain "$d" || continue
        scan_domain "$d"
    done < "$hosts"

    log INFO "All domain scans completed."
}

# Set default values
domain=False
hosts=False
out=False
alive=False
exclude=False

# Check if no arguments provided
if [ $# -eq 0 ]; then
    Usage
fi

# Process command line arguments
while [ -n "$1" ]; do
    case $1 in
        -d|--domain)  domain=$2; shift ;;
        -l|--list)    hosts=$2; shift ;;
        -o|--output)  out=$2; shift ;;
        -x|--alive)   alive=$2; shift ;;
        -e|--exclude) exclude=$2; shift ;;
        -v|--version) echo "$PRG v$VERSION"; exit 0 ;;
        -h|--help)    Usage ;;
        *) log ERROR "Unknown parameter: $1"; Usage ;;
    esac
    shift
done

if [ "$domain" != "False" ] && [ "$hosts" != "False" ]; then
    log ERROR "Cannot use -d and -l together. Choose one."
    Usage
fi

if [ "$domain" != "False" ]; then
    validate_domain "$domain" || exit 1
    log INFO "Log file: $LOG_FILE"
    scan_domain "$domain" || exit 1
elif [ "$hosts" != "False" ]; then
    LIST
else
    Usage
fi
