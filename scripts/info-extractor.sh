#!/bin/bash
if [[ ${1:-} == --help || ${1:-} == -h ]]; then
    [[ $# == 1 ]] || { printf 'Help takes no additional arguments.\n' >&2; exit 2; }
    cat <<'EOF'
Linux Info Extractor
Usage: bash scripts/info-extractor.sh [--help]

Print network information, CPU/memory usage, services and large /home files.
Normal execution contacts ifconfig.me and reads local system information.
--help performs no collection or network activity.
EOF
    exit 0
fi
if (( $# )); then
    printf 'Usage: bash scripts/info-extractor.sh [--help]\n' >&2
    exit 2
fi
echo "======================================"
echo "           INFO EXTRACTOR"
echo "======================================"
echo


#1. Get Public IP Address

echo "PUBLIC IP ADDRESS"
echo "---------------------"

PUBLIC_IP=$(curl -fsS --max-time 5 https://ifconfig.me/ip 2>/dev/null)

if [ -n "$PUBLIC_IP" ]; then
    echo "Public IP: $PUBLIC_IP"
else
    echo "Unable to retrieve public IP."
fi

echo


#2. Get Private IP Address

echo "PRIVATE IP ADDRESS"
echo "---------------------"

PRIVATE_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '
{
    for (i=1; i<=NF; i++) {
        if ($i == "src") {
            print $(i+1)
            exit
        }
    }
}')

if [ -n "$PRIVATE_IP" ]; then
    echo "Private IP: $PRIVATE_IP"
else
    echo "Unable to retrieve private IP."
fi

echo


#3.Get MAC Address

echo "MAC ADDRESS"
echo "--------------"

INTERFACE=$(ip route | awk '/default/ {print $5; exit}')

if [ -n "$INTERFACE" ] && [ -f "/sys/class/net/$INTERFACE/address" ]; then

    MAC=$(cat "/sys/class/net/$INTERFACE/address")

    MASKED_MAC=$(echo "$MAC" | awk -F: '
    {
        print $1 ":" $2 ":" $3 ":XX:XX:XX"
    }')

    echo "Network Interface: $INTERFACE"
    echo "Masked MAC Address: $MASKED_MAC"

else
    echo "Unable to retrieve MAC address."
fi

echo


#4. Top 5 Processes by CPU Usage

echo "TOP 5 PROCESSES BY CPU USAGE"
echo "--------------------------------"

ps -eo pid,comm,%cpu --sort=-%cpu |
    awk '
        NR == 1 {
            print
            next
        }

        $2 != "ps" && $2 != "awk" && $2 != "head" {
            print
            count++
        }

        count == 5 {
            exit
        }
    '
echo


#5. Memory Usage

echo "MEMORY USAGE"
echo "---------------"

free -h

echo


#6. Active System Services

echo "ACTIVE SYSTEM SERVICES"
echo "-------------------------"

if command -v systemctl >/dev/null 2>&1; then
    systemctl list-units \
        --type=service \
        --state=running \
        --no-pager
else
    service --status-all 2>/dev/null | grep '\[ + \]'
fi

echo


#7. Top 10 Largest Files in /home

echo "TOP 10 LARGEST FILES IN /home"
echo "--------------------------------"

find /home -type f -printf '%s %p\n' 2>/dev/null |
    sort -nr |
    head -n 10 |
    numfmt --field=1 --to=iec

echo

echo "======================================"
echo "          END OF REPORT"
echo "======================================"
