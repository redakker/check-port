# Docker Port Checker Script

A **Docker-aware port checking utility** for Linux servers.
It helps you quickly check which TCP ports are free, which are used by Docker containers, and shows **free port intervals** in a readable and color-coded format.

---

## Features

- Check a **specific port** for usage.
- Show **highest used port** and **next free port** if no arguments are given.
- Display **all free port intervals (1-65535)** with Docker container information.
- **Color-coded output** for better readability:
  - **Green** → Free ports
  - **Yellow** → Ports used by Docker containers with container name

---

## Usage

```bash
# Check a specific port
./check-port.sh 8080

# Show highest used port and next free port
./check-port.sh

# Show all free port intervals and Docker-used ports
./check-port.sh -f

# Show help
./check-port.sh -h