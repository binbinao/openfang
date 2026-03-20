#!/usr/bin/env bash
# OpenFang简化重启脚本
# 用法: ./scripts/restart-simple.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 颜色定义
CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m' # 无颜色

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }

# 主函数
main() {
    echo -e "${CYAN}🔄 重启OpenFang...${NC}"
    echo ""
    
    # 调用现有的restart.sh脚本
    info "正在执行重启操作..."
    "$SCRIPT_DIR/restart.sh" restart
    
    echo ""
    ok "重启完成"
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --help, -h    显示此帮助信息"
    echo "  --build       重新构建(debug版本)并重启"
    echo "  --release     重新构建(release版本)并重启"
    echo ""
    echo "如果没有选项，将执行普通重启"
    echo ""
    echo "更多功能请使用: ./scripts/restart.sh"
}

# 脚本入口
case "${1:-}" in
    "")
        main
        ;;
    "--help" | "-h")
        show_help
        ;;
    "--build")
        "$SCRIPT_DIR/restart.sh" build
        ;;
    "--release")
        "$SCRIPT_DIR/restart.sh" release
        ;;
    *)
        echo "错误: 未知选项 '$1'"
        echo ""
        show_help
        exit 1
        ;;
esac