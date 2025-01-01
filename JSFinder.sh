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

VERSION="1.0"
PRG=${0##*/}

Usage(){
	echo "Usage:"
	echo "    -d, --domain       - Target domain to scan"
	echo "    -l, --list        - File containing list of domains"
	echo "    -o, --output      - Save all subdomains to output file"
	echo "    -x, --alive       - Save live subdomains to output file"
	echo "    -t, --thread      - Number of threads (Default: 40)"
	echo "    -h, --help        - Display this help menu"
	echo ""
	echo "Examples:"
	echo "    $PRG -d example.com"
	echo "    $PRG -l domains.txt"
	echo "    $PRG -d example.com -o results.txt -x alive.txt"
	exit 1
}

wayback() {
	# Query WayBackMachine for historical subdomain records
	curl -sk "http://web.archive.org/cdx/search/cdx?url=*.$domain&output=txt&fl=original&collapse=urlkey&page=" | 
	awk -F/ '{gsub(/:.*/, "", $3); print $3}' | sort -u > tmp-wayback-$domain
	echo "[*] WayBackMachine: $(wc -l < tmp-wayback-$domain)"
}

crt() {
	# Query crt.sh for SSL certificate records
	curl -sk "https://crt.sh/?q=%.$domain&output=json" | 
	tr ',' '\n' | awk -F'"' '/name_value/ {gsub(/\*\./, "", $4); gsub(/\\n/,"\n",$4);print $4}' | 
	sort -u > tmp-crt-$domain
	echo "[*] crt.sh: $(wc -l < tmp-crt-$domain)"
}

abuseipdb() {
	# Query AbuseIPDB for subdomain information
	curl -s "https://www.abuseipdb.com/whois/$domain" -H "user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" | grep -oP '(?<=<li>)[^<]+' | grep -v "^[[:space:]]*$" | sed -e "s/$/.$domain/" | sort -u > tmp-abuseipdb-$domain
	echo "[*] AbuseIPDB: $(wc -l < tmp-abuseipdb-$domain)"
}

securitytrails() {
	# Query SecurityTrails API for subdomains
	local ST_API_KEY="YOUR_API_KEY_HERE"
	local response=$(curl -s "https://api.securitytrails.com/v1/domain/$domain/subdomains" \
		-H "APIKEY: $ST_API_KEY" \
		-H "Accept: application/json")
	
	if echo "$response" | jq -e '.subdomains' >/dev/null 2>&1; then
		echo "$response" | jq -r '.subdomains[]' | sed "s/$/.$domain/" | sort -u > tmp-securitytrails-$domain
		echo "[*] SecurityTrails: $(wc -l < tmp-securitytrails-$domain)"
	else
		echo "[!] SecurityTrails API error: $(echo "$response" | jq -r '.message // "Unknown error"')"
		touch tmp-securitytrails-$domain
	fi
}

Findomain() {
	# Run Findomain for subdomain enumeration
	findomain -t $domain -u tmp-findomain-$domain &>/dev/null
	echo "[*] Findomain: $(wc -l < tmp-findomain-$domain)"
}

Subfinder() {
	# Run Subfinder for subdomain enumeration
	subfinder -all -silent -d $domain 1> tmp-subfinder-$domain 2>/dev/null
	echo "[*] SubFinder: $(wc -l < tmp-subfinder-$domain)"
}

Amass() {
	# Run Amass for passive subdomain enumeration
	amass enum -passive -norecursive -noalts -d $domain 1> tmp-amass-$domain 2>/dev/null
	echo "[*] Amass: $(wc -l < tmp-amass-$domain)"
}

Assetfinder() {
	# Run Assetfinder for subdomain discovery
	assetfinder --subs-only $domain > tmp-assetfinder-$domain
	echo "[*] AssetFinder: $(wc -l < tmp-assetfinder-$domain)"
}

PROCESS_RESULTS() {
	# Count total unique subdomains using anew
	echo "[+] Processing results with anew..."
	
	# Create temporary file for all subdomains
	for file in tmp-*; do
		cat "$file" | anew "tmp-all-$domain.txt" >/dev/null
	done
	
	result=$(wc -l < "tmp-all-$domain.txt")
	echo "[+] Total unique subdomains: ${result}"
	
	# Save all subdomains to output file if specified
	if [ "$out" != False ]; then
		cp "tmp-all-$domain.txt" "$out"
		echo "[+] All subdomains saved to: $out"
	fi

	# Check for live subdomains using httpx
	echo "[+] Checking for live subdomains with httpx..."
	cat "tmp-all-$domain.txt" | httpx -silent | anew "tmp-alive-$domain.txt" >/dev/null
	
	# Save live subdomains to output file if specified
	if [ "$alive" != False ]; then
		cp "tmp-alive-$domain.txt" "$alive"
		echo "[+] Live subdomains saved to: $alive"
	fi

	# Scan for JavaScript files using katana
	echo "[+] Running katana scan for JavaScript files..."
	katana -list "tmp-alive-$domain.txt" -d 5 -jc | grep ".js$" | anew "js-files-$domain.txt" >/dev/null
	echo "[+] JavaScript files saved to: js-files-$domain.txt"
	
	# Clean up temporary files
	rm tmp-*
}

LIST() {
	# Process multiple domains from input file
	while read domain; do
		echo "[+] Scanning domain: ${domain}"
		wayback
		crt
		abuseipdb
		securitytrails
		Findomain 
		Subfinder 
		Amass 
		Assetfinder
		PROCESS_RESULTS
	done < $hosts
}

# Set default values
domain=False
hosts=False
out=False
alive=False
thread=40

# Process command line arguments
while [ -n "$1" ]; do
	case $1 in
		-d|--domain) domain=$2; shift ;;
		-l|--list) hosts=$2; shift ;;
		-o|--output) out=$2; shift ;;
		-x|--alive) alive=$2; shift ;;
		-t|--thread) thread=$2; shift ;;
		-h|--help) Usage ;;
		*) echo "[-] Unknown parameter: $1"; Usage ;;
	esac
	shift
done

# Main program execution
if [ "$domain" != "False" ]; then
	wayback
	crt
	abuseipdb
	securitytrails
	Findomain 
	Subfinder
	Amass 
	Assetfinder
	PROCESS_RESULTS
fi

[ "$hosts" != "False" ] && LIST
