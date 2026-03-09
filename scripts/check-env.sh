#!/usr/bin/env bash
# OpenFang环境检查脚本
# 用法: ./scripts/check-env.sh

set -euo pipefail

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # 无颜色

ok()    { echo -e "${GREEN}[✓]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[!]${NC}    $*"; }
err()   { echo -e "${RED}[✗]${NC}    $*"; }
info()  { echo -e "${CYAN}[i]${NC}    $*"; }

# 检查Rust工具链
check_rust() {
    info "检查Rust工具链..."
    
    if command -v rustc > /dev/null 2>&1; then
        local rust_version=$(rustc --version | cut -d' ' -f2)
        ok "Rust已安装: $rust_version"
    else
        err "Rust未安装，请先安装Rust工具链"
        return 1
    fi
    
    if command -v cargo > /dev/null 2>&1; then
        local cargo_version=$(cargo --version | cut -d' ' -f2)
        ok "Cargo已安装: $cargo_version"
    else
        err "Cargo未安装"
        return 1
    fi
    
    return 0
}

# 检查openfang二进制文件
check_openfang_binary() {
    info "检查openfang二进制文件..."
    
    OPENFANG_BIN="${OPENFANG_BIN:-$(which openfang 2>/dev/null || echo "$HOME/.cargo/bin/openfang")}"
    
    if [ -f "$OPENFANG_BIN" ] && [ -x "$OPENFANG_BIN" ]; then
        ok "openfang二进制文件存在: $OPENFANG_BIN"
        local version=$("$OPENFANG_BIN" --version 2>/dev/null || echo "未知版本")
        ok "openfang版本: $version"
    else
        warn "openfang二进制文件不存在或不可执行"
        warn "请运行: cargo build --release -p openfang-cli"
        return 1
    fi
    
    return 0
}

# 检查项目依赖
check_dependencies() {
    info "检查项目依赖..."
    
    if [ -f "Cargo.toml" ]; then
        ok "Cargo.toml配置文件存在"
        
        # 检查是否安装了依赖
        if cargo check --quiet 2>/dev/null; then
            ok "项目依赖已正确安装"
        else
            warn "项目依赖未完全安装，运行: cargo build"
        fi
    else
        err "Cargo.toml配置文件不存在"
        return 1
    fi
    
    return 0
}

# 检查守护进程状态
check_daemon_status() {
    info "检查守护进程状态..."
    
    if pgrep -f "openfang start" > /dev/null 2>&1; then
        ok "OpenFang守护进程正在运行"
        ps aux | grep "[o]penfang start" | awk '{printf "  PID: %s | CPU: %s%% | MEM: %s%% | 启动时间: %s %s\n", $2, $3, $4, $9, $10}'
    else
        warn "OpenFang守护进程未运行"
    fi
}

# 主函数
main() {
    echo -e "${CYAN}🔍 检查OpenFang环境...${NC}"
    echo ""
    
    local all_checks_passed=true
    
    # 执行各项检查
    if ! check_rust; then
        all_checks_passed=false
    fi
    echo ""
    
    if ! check_openfang_binary; then
        all_checks_passed=false
    fi
    echo ""
    
    if ! check_dependencies; then
        all_checks_passed=false
    fi
    echo ""
    
    check_daemon_status
    echo ""
    
    if $all_checks_passed; then
        echo -e "${GREEN}✅ 所有环境检查通过！${NC}"
    else
        echo -e "${YELLOW}⚠️  部分环境检查未通过，请根据提示修复问题${NC}"
    fi
}

# 脚本入口
case "${1:-}" in
    "--help" | "-h")
        echo "用法: $0 [选项]"
        echo ""
        echo "选项:"
        echo "  --help, -h    显示此帮助信息"
        echo ""
        echo "此脚本检查OpenFang运行所需的环境依赖"
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