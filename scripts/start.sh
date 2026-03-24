#!/usr/bin/env bash
# OpenFang启动脚本
# 用法: ./scripts/start.sh

set -euo pipefail

# Ensure Rust toolchain is in PATH
if ! command -v cargo &>/dev/null; then
    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    elif [ -d "$HOME/.rustup/toolchains" ]; then
        for tc in "$HOME"/.rustup/toolchains/*/bin; do
            [ -d "$tc" ] && export PATH="$tc:$PATH" && break
        done
    fi
fi

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Resolve the openfang binary: env override > PATH > project release > project debug > cargo install
if [ -n "${OPENFANG_BIN:-}" ]; then
    : # user override, keep it
elif command -v openfang &>/dev/null; then
    OPENFANG_BIN="$(command -v openfang)"
elif [ -x "$PROJECT_DIR/target/release/openfang" ]; then
    OPENFANG_BIN="$PROJECT_DIR/target/release/openfang"
elif [ -x "$PROJECT_DIR/target/debug/openfang" ]; then
    OPENFANG_BIN="$PROJECT_DIR/target/debug/openfang"
else
    OPENFANG_BIN="$HOME/.cargo/bin/openfang"
fi

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # 无颜色

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }

# 检查openfang守护进程是否在运行
is_running() {
    pgrep -f "openfang start" > /dev/null 2>&1
}

# 显示当前状态
show_status() {
    if is_running; then
        ok "OpenFang守护进程正在运行"
        ps aux | grep "[o]penfang start" | awk '{printf "  PID: %s | CPU: %s%% | MEM: %s%% | 启动时间: %s %s\n", $2, $3, $4, $9, $10}'
        echo ""
        "$OPENFANG_BIN" status 2>/dev/null || true
    else
        warn "OpenFang守护进程未运行"
    fi
}

# 启动守护进程
do_start() {
    info "正在启动OpenFang守护进程..."
    nohup "$OPENFANG_BIN" start > /tmp/openfang-daemon.log 2>&1 &
    
    # 等待启动（最多5秒）
    local count=0
    while ! is_running && [ $count -lt 5 ]; do
        sleep 1
        count=$((count + 1))
    done

    if is_running; then
        ok "守护进程已启动（日志: /tmp/openfang-daemon.log）"
    else
        warn "启动守护进程失败！检查日志:"
        tail -20 /tmp/openfang-daemon.log 2>/dev/null
        exit 1
    fi
}

# 主函数
main() {
    echo -e "${CYAN}🚀 启动OpenFang...${NC}"
    echo ""
    
    if is_running; then
        warn "OpenFang守护进程已经在运行"
        show_status
        exit 0
    fi
    
    do_start
    echo ""
    show_status
}

# 脚本入口
case "${1:-}" in
    "--help" | "-h")
        echo "用法: $0 [选项]"
        echo ""
        echo "选项:"
        echo "  --help, -h    显示此帮助信息"
        echo "  --status      只显示状态，不启动"
        echo ""
        echo "如果没有选项，将启动OpenFang守护进程"
        exit 0
        ;;
    "--status")
        show_status
        exit 0
        ;;
    "")
        main
        ;;
    *)
        echo "错误: 未知选项 '$1'"
        echo "使用 --help 查看帮助信息"
        exit 1
        ;;
esac