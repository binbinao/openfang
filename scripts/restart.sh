#!/usr/bin/env bash
# Quick restart script for OpenFang daemon
# Usage:
#   ./scripts/restart.sh          # restart only
#   ./scripts/restart.sh build    # rebuild (debug) + restart
#   ./scripts/restart.sh release  # rebuild (release) + restart
#   ./scripts/restart.sh status   # show daemon status

set -euo pipefail

OPENFANG_BIN="${OPENFANG_BIN:-$(which openfang 2>/dev/null || echo "$HOME/.cargo/bin/openfang")}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-restart}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERR]${NC}   $*"; }

# Check if openfang daemon is running
is_running() {
    pgrep -f "openfang start" > /dev/null 2>&1
}

# Show current status
show_status() {
    if is_running; then
        ok "OpenFang daemon is running"
        ps aux | grep "[o]penfang start" | awk '{printf "  PID: %s | CPU: %s%% | MEM: %s%% | Started: %s %s\n", $2, $3, $4, $9, $10}'
        echo ""
        "$OPENFANG_BIN" status 2>/dev/null || true
    else
        warn "OpenFang daemon is NOT running"
    fi
}

# Stop the daemon
do_stop() {
    if is_running; then
        info "Stopping OpenFang daemon..."
        "$OPENFANG_BIN" stop 2>/dev/null || true

        # Wait for graceful shutdown (max 10s)
        local count=0
        while is_running && [ $count -lt 10 ]; do
            sleep 1
            count=$((count + 1))
        done

        # Force kill if still running
        if is_running; then
            warn "Graceful stop timed out, force killing..."
            pkill -9 -f "openfang start" 2>/dev/null || true
            sleep 1
        fi

        ok "Daemon stopped"
    else
        info "Daemon is not running, skip stop"
    fi
}

# Start the daemon
do_start() {
    info "Starting OpenFang daemon..."
    nohup "$OPENFANG_BIN" start > /tmp/openfang-daemon.log 2>&1 &
    
    # Wait for startup (max 5s)
    local count=0
    while ! is_running && [ $count -lt 5 ]; do
        sleep 1
        count=$((count + 1))
    done

    if is_running; then
        ok "Daemon started (log: /tmp/openfang-daemon.log)"
    else
        err "Failed to start daemon! Check log:"
        tail -20 /tmp/openfang-daemon.log 2>/dev/null
        exit 1
    fi
}

# Build the project
do_build() {
    local profile="${1:-debug}"
    info "Building openfang ($profile)..."
    
    cd "$PROJECT_DIR"
    if [ "$profile" = "release" ]; then
        cargo build --release -p openfang-cli
        sudo cp -f target/release/openfang "$OPENFANG_BIN"
    else
        cargo build -p openfang-cli
        sudo cp -f target/debug/openfang "$OPENFANG_BIN"
    fi
    
    ok "Build complete ($profile) -> $OPENFANG_BIN"
}

# Main
case "$MODE" in
    restart|r)
        echo -e "${CYAN}🔄 Restarting OpenFang...${NC}"
        echo ""
        do_stop
        do_start
        echo ""
        show_status
        ;;
    build|b)
        echo -e "${CYAN}🔨 Rebuild (debug) + Restart OpenFang...${NC}"
        echo ""
        do_stop
        do_build debug
        do_start
        echo ""
        show_status
        ;;
    release|rel)
        echo -e "${CYAN}🚀 Rebuild (release) + Restart OpenFang...${NC}"
        echo ""
        do_stop
        do_build release
        do_start
        echo ""
        show_status
        ;;
    status|s)
        show_status
        ;;
    stop)
        do_stop
        ;;
    start)
        do_start
        show_status
        ;;
    *)
        echo "Usage: $0 {restart|build|release|status|stop|start}"
        echo ""
        echo "Commands:"
        echo "  restart, r    Stop + Start the daemon (default)"
        echo "  build, b      Rebuild (debug) + restart"
        echo "  release, rel  Rebuild (release) + restart"
        echo "  status, s     Show daemon status"
        echo "  stop          Stop the daemon"
        echo "  start         Start the daemon"
        exit 1
        ;;
esac
