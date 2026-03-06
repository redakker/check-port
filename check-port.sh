#!/bin/bash

# ------------------------------------------------------------
# Docker-aware port check utility
# - check single port
# - show highest used port & next free port
# - show free port intervals (1-65535) with Docker container info
# - colorized output
# ------------------------------------------------------------

# Colors
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

show_help() {
cat << EOF
Usage:
  $(basename "$0") [PORT]       Check a specific port
  $(basename "$0")              Show highest used port & next free
  $(basename "$0") -f           Show free port intervals (1-65535) with Docker container info

Options:
  -h          Show this help message
  -f          Show free port intervals (1-65535) with Docker containers

Examples:
  $(basename "$0") 8080
  $(basename "$0")
  $(basename "$0") -f
EOF
}

# Show help
if [[ "$1" == "-h" ]]; then
    show_help
    exit 0
fi

# ------------------------------------------------------------
# Function: check a single port
# ------------------------------------------------------------
check_port() {
    local PORT=$1
    if ss -tuln | grep -q ":$PORT "; then
        echo -e "${YELLOW}Port $PORT is in use${RESET}"
        docker ps --format "{{.Names}} {{.Ports}}" | grep -q ":$PORT " && \
        docker ps --format "{{.Names}} {{.Ports}}" | grep ":$PORT " | awk '{print "-> Docker container: "$1}'
    else
        echo -e "${GREEN}Port $PORT is free${RESET}"
    fi
}

# ------------------------------------------------------------
# Function: show free port intervals with Docker info
# ------------------------------------------------------------
show_free_ranges() {
    echo "Collecting port info... (this may take a few seconds)"

    # Docker ports
    declare -A DOCKER_PORTS
    while read -r line; do
        CONTAINER=$(echo "$line" | awk '{print $1}')
        PORTS=$(echo "$line" | awk '{$1=""; print $0}')
        for p in $(echo "$PORTS" | grep -o '[0-9]*->'); do
            P=${p%%->}
            DOCKER_PORTS[$P]=$CONTAINER
        done
    done < <(docker ps --format "{{.Names}} {{.Ports}}")

    # System TCP used ports
    USED_PORTS=$(ss -tuln | awk '{print $5}' | grep -o '[0-9]*$' | grep -v '^$' | sort -n | uniq)

    LAST_USED=0
    FREE_RANGES=()
    OUTPUT=()

    for P in $USED_PORTS; do
        # Free range before this port
        if (( P > LAST_USED + 1 )); then
            FREE_RANGES+=("$((LAST_USED+1))-$((P-1))")
        fi
        # Docker used port
        if [[ -n "${DOCKER_PORTS[$P]}" ]]; then
            OUTPUT+=("${YELLOW}$P -> ${DOCKER_PORTS[$P]}${RESET}")
        fi
        LAST_USED=$P
    done

    # Remaining free ports after last used
    if (( LAST_USED < 65535 )); then
        FREE_RANGES+=("$((LAST_USED+1))-65535")
    fi

    # Print free ranges in green, max 5 per line
    echo -e "${GREEN}Free port intervals:${RESET}"
    LINE=""
    COUNT=0
    for R in "${FREE_RANGES[@]}"; do
        LINE+="$R, "
        ((COUNT++))
        if (( COUNT % 5 == 0 )); then
            echo -e "${GREEN}${LINE%, }${RESET}"
            LINE=""
        fi
    done
    [[ -n "$LINE" ]] && echo -e "${GREEN}${LINE%, }${RESET}"

    # Print Docker ports
    if (( ${#OUTPUT[@]} > 0 )); then
        echo -e "\n${YELLOW}Docker-used ports:${RESET}"
        for entry in "${OUTPUT[@]}"; do
            echo -e "$entry"
        done
    fi
}

# ------------------------------------------------------------
# If -f flag -> show free ranges
# ------------------------------------------------------------
if [[ "$1" == "-f" ]]; then
    show_free_ranges
    exit 0
fi

# ------------------------------------------------------------
# If single port argument
# ------------------------------------------------------------
if [[ -n "$1" ]]; then
    PORT="$1"
    if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
        echo "Error: port must be a number"
        exit 1
    fi
    check_port "$PORT"
    exit 0
fi

# ------------------------------------------------------------
# No arguments -> highest used port & next free port
# ------------------------------------------------------------
LAST_PORT=$(ss -tuln | awk '{print $5}' | grep -o '[0-9]*$' | grep -v '^$' | sort -n | tail -1)
[[ -z "$LAST_PORT" ]] && LAST_PORT=0
NEXT_PORT=$((LAST_PORT+1))
echo "Highest used port : $LAST_PORT"
echo "Next free port    : $NEXT_PORT"
