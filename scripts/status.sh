#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
# OpenFang 状态检查脚本
# 用法: ./scripts/status.sh [--json] [--verbose]
#
# 检查项：
#   1. 守护进程 (Gateway) 运行状态
#   2. API 健康检查 (/api/health)
#   3. 详细健康信息 (/api/health/detail)
#   4. 内核状态 (/api/status)
#   5. Agent 列表与状态
#   6. Channel 适配器状态
#   7. Hands 状态
#   8. 数据库连通性
#   9. 资源使用 (CPU/内存/磁盘)
#  10. 网络/P2P 状态
#  11. 集成/扩展健康
#  12. Prometheus 指标摘要
# ═══════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Rust 工具链路径 ──────────────────────────────────────────────────
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

# ── 解析二进制路径 ──────────────────────────────────────────────────
if [ -n "${OPENFANG_BIN:-}" ]; then
    : # 用户指定
elif command -v openfang &>/dev/null; then
    OPENFANG_BIN="$(command -v openfang)"
elif [ -x "$PROJECT_DIR/target/release/openfang" ]; then
    OPENFANG_BIN="$PROJECT_DIR/target/release/openfang"
elif [ -x "$PROJECT_DIR/target/debug/openfang" ]; then
    OPENFANG_BIN="$PROJECT_DIR/target/debug/openfang"
else
    OPENFANG_BIN="$HOME/.cargo/bin/openfang"
fi

# ── 参数解析 ────────────────────────────────────────────────────────
JSON_MODE=false
VERBOSE=false
for arg in "$@"; do
    case "$arg" in
        --json)    JSON_MODE=true ;;
        --verbose) VERBOSE=true ;;
        --help|-h)
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --json      以 JSON 格式输出结果"
            echo "  --verbose   显示更多详细信息"
            echo "  --help, -h  显示此帮助信息"
            exit 0
            ;;
    esac
done

# ── 颜色与格式 ──────────────────────────────────────────────────────
if [ "$JSON_MODE" = true ]; then
    # JSON 模式下禁用颜色
    RED='' GREEN='' YELLOW='' CYAN='' MAGENTA='' BOLD='' DIM='' NC=''
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
fi

ok()    { [ "$JSON_MODE" = false ] && echo -e "  ${GREEN}✓${NC}  $*"; }
fail()  { [ "$JSON_MODE" = false ] && echo -e "  ${RED}✗${NC}  $*"; }
warn()  { [ "$JSON_MODE" = false ] && echo -e "  ${YELLOW}!${NC}  $*"; }
info()  { [ "$JSON_MODE" = false ] && echo -e "  ${CYAN}ℹ${NC}  $*"; }
header(){ [ "$JSON_MODE" = false ] && echo -e "\n${BOLD}${CYAN}═══ $* ═══${NC}"; }
detail(){ [ "$JSON_MODE" = false ] && [ "$VERBOSE" = true ] && echo -e "    ${DIM}$*${NC}"; }

# ── JSON 收集器 ─────────────────────────────────────────────────────
JSON_RESULT="{}"
json_set() {
    # json_set ".key" "value"
    JSON_RESULT=$(echo "$JSON_RESULT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
key = '$1'
val = '''$2'''
# 尝试解析为 JSON，否则当作字符串
try:
    parsed = json.loads(val)
except:
    parsed = val
# 支持嵌套 key (e.g. '.gateway.status')
keys = key.strip('.').split('.')
d = data
for k in keys[:-1]:
    if k not in d:
        d[k] = {}
    d = d[k]
d[keys[-1]] = parsed
json.dump(data, sys.stdout)
" 2>/dev/null || echo "$JSON_RESULT")
}

# ── 读取 daemon.json ────────────────────────────────────────────────
OPENFANG_HOME="${OPENFANG_HOME:-$HOME/.openfang}"
DAEMON_JSON="$OPENFANG_HOME/daemon.json"
DAEMON_PID=""
DAEMON_ADDR=""
BASE_URL=""

read_daemon_info() {
    if [ -f "$DAEMON_JSON" ]; then
        DAEMON_PID=$(python3 -c "import json; d=json.load(open('$DAEMON_JSON')); print(d.get('pid',''))" 2>/dev/null || true)
        DAEMON_ADDR=$(python3 -c "import json; d=json.load(open('$DAEMON_JSON')); print(d.get('listen_addr',''))" 2>/dev/null || true)
        if [ -n "$DAEMON_ADDR" ]; then
            BASE_URL="http://$DAEMON_ADDR"
        fi
    fi
}

# ── API 请求辅助函数 ────────────────────────────────────────────────
api_get() {
    local endpoint="$1"
    local timeout="${2:-5}"
    curl -sf --max-time "$timeout" "${BASE_URL}${endpoint}" 2>/dev/null || echo ""
}

# ═══════════════════════════════════════════════════════════════════════
# 检查 1: 守护进程 (Gateway) 状态
# ═══════════════════════════════════════════════════════════════════════
check_gateway() {
    header "守护进程 (Gateway)"

    read_daemon_info

    local gateway_status="stopped"
    local gateway_pid=""
    local gateway_addr=""
    local gateway_uptime=""
    local gateway_cpu=""
    local gateway_mem=""
    local gateway_version=""

    # 检查进程是否存在
    if pgrep -f "openfang start" > /dev/null 2>&1; then
        gateway_pid=$(pgrep -f "openfang start" | head -1)

        # 验证 PID 匹配
        if [ -n "$DAEMON_PID" ] && [ "$DAEMON_PID" != "$gateway_pid" ]; then
            warn "daemon.json 记录的 PID ($DAEMON_PID) 与实际 PID ($gateway_pid) 不匹配"
        fi

        gateway_status="running"
        gateway_addr="${DAEMON_ADDR:-unknown}"

        # 获取进程资源信息
        local ps_info
        ps_info=$(ps -p "$gateway_pid" -o pid=,pcpu=,pmem=,etime= 2>/dev/null || true)
        if [ -n "$ps_info" ]; then
            gateway_cpu=$(echo "$ps_info" | awk '{print $2}')
            gateway_mem=$(echo "$ps_info" | awk '{print $3}')
            gateway_uptime=$(echo "$ps_info" | awk '{print $4}')
        fi

        ok "守护进程正在运行"
        info "PID: ${gateway_pid}"
        info "监听地址: ${gateway_addr}"
        info "CPU: ${gateway_cpu:-N/A}%  |  内存: ${gateway_mem:-N/A}%  |  运行时间: ${gateway_uptime:-N/A}"

        # 尝试获取版本
        if [ -n "$BASE_URL" ]; then
            local version_resp
            version_resp=$(api_get "/api/version")
            if [ -n "$version_resp" ]; then
                gateway_version=$(echo "$version_resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('version',''))" 2>/dev/null || true)
                local git_sha
                git_sha=$(echo "$version_resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('git_sha',''))" 2>/dev/null || true)
                info "版本: ${gateway_version} (${git_sha:-unknown})"
            fi
        fi
    else
        fail "守护进程未运行"
        if [ -f "$DAEMON_JSON" ]; then
            warn "存在旧的 daemon.json (PID: $DAEMON_PID)，可能未正常关闭"
        fi
    fi

    # 检查二进制文件
    if [ -x "$OPENFANG_BIN" ]; then
        local bin_version
        bin_version=$("$OPENFANG_BIN" --version 2>/dev/null || echo "unknown")
        detail "二进制文件: $OPENFANG_BIN ($bin_version)"
    else
        warn "二进制文件未找到: $OPENFANG_BIN"
    fi

    json_set ".gateway" "{\"status\":\"$gateway_status\",\"pid\":\"$gateway_pid\",\"address\":\"$gateway_addr\",\"uptime\":\"$gateway_uptime\",\"cpu\":\"$gateway_cpu\",\"memory\":\"$gateway_mem\",\"version\":\"$gateway_version\"}"
}

# ═══════════════════════════════════════════════════════════════════════
# 检查 2: API 健康状态
# ═══════════════════════════════════════════════════════════════════════
check_health() {
    header "API 健康检查"

    if [ -z "$BASE_URL" ]; then
        fail "无法连接 (守护进程未运行)"
        json_set ".health" "{\"status\":\"unreachable\"}"
        return
    fi

    # 基础健康 (无需认证)
    local health_resp
    health_resp=$(api_get "/api/health")
    if [ -z "$health_resp" ]; then
        fail "健康端点无响应 ($BASE_URL/api/health)"
        json_set ".health" "{\"status\":\"unreachable\"}"
        return
    fi

    local health_status
    health_status=$(echo "$health_resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null || echo "unknown")

    if [ "$health_status" = "ok" ]; then
        ok "API 健康: ${GREEN}OK${NC}"
    elif [ "$health_status" = "degraded" ]; then
        warn "API 健康: ${YELLOW}降级${NC} (数据库可能异常)"
    else
        fail "API 健康: ${RED}${health_status}${NC}"
    fi

    # 详细健康 (可能需要认证，静默失败)
    local detail_resp
    detail_resp=$(api_get "/api/health/detail")
    if [ -n "$detail_resp" ]; then
        local uptime_secs panic_count restart_count agent_count db_status
        uptime_secs=$(echo "$detail_resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('uptime_seconds',0))" 2>/dev/null || echo "0")
        panic_count=$(echo "$detail_resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('panic_count',0))" 2>/dev/null || echo "0")
        restart_count=$(echo "$detail_resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('restart_count',0))" 2>/dev/null || echo "0")
        agent_count=$(echo "$detail_resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('agent_count',0))" 2>/dev/null || echo "0")
        db_status=$(echo "$detail_resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('database','unknown'))" 2>/dev/null || echo "unknown")

        # 格式化运行时间
        local uptime_fmt
        if [ "$uptime_secs" -ge 86400 ]; then
            uptime_fmt="$((uptime_secs / 86400))天 $((uptime_secs % 86400 / 3600))时"
        elif [ "$uptime_secs" -ge 3600 ]; then
            uptime_fmt="$((uptime_secs / 3600))时 $((uptime_secs % 3600 / 60))分"
        else
            uptime_fmt="$((uptime_secs / 60))分 $((uptime_secs % 60))秒"
        fi

        info "运行时间: ${uptime_fmt}"
        info "Agent 数量: ${agent_count}"

        if [ "$db_status" = "connected" ]; then
            ok "数据库: 已连接"
        else
            fail "数据库: ${db_status}"
        fi

        if [ "$panic_count" -gt 0 ]; then
            warn "Panic 次数: ${panic_count}"
        fi
        if [ "$restart_count" -gt 0 ]; then
            warn "重启次数: ${restart_count}"
        fi

        json_set ".health" "{\"status\":\"$health_status\",\"uptime_seconds\":$uptime_secs,\"panic_count\":$panic_count,\"restart_count\":$restart_count,\"agent_count\":$agent_count,\"database\":\"$db_status\"}"
    else
        json_set ".health" "{\"status\":\"$health_status\"}"
    fi
}

# ═══════════════════════════════════════════════════════════════════════
# 检查 3: 内核与 Agent 状态
# ═══════════════════════════════════════════════════════════════════════
check_agents() {
    header "Agent 状态"

    if [ -z "$BASE_URL" ]; then
        fail "无法获取 (守护进程未运行)"
        json_set ".agents" "[]"
        return
    fi

    local status_resp
    status_resp=$(api_get "/api/status")
    if [ -z "$status_resp" ]; then
        fail "状态端点无响应"
        json_set ".agents" "[]"
        return
    fi

    local default_provider default_model
    default_provider=$(echo "$status_resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('default_provider',''))" 2>/dev/null || true)
    default_model=$(echo "$status_resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('default_model',''))" 2>/dev/null || true)

    info "默认模型: ${default_provider}/${default_model}"

    # 提取 agent 列表
    local agents_json
    agents_json=$(echo "$status_resp" | python3 -c "
import sys, json
data = json.load(sys.stdin)
agents = data.get('agents', [])
if not agents:
    print('EMPTY')
else:
    for a in agents:
        state = a.get('state', 'Unknown')
        name = a.get('name', 'unnamed')
        model = a.get('model_name', '')
        provider = a.get('model_provider', '')
        mode = a.get('mode', '')
        aid = a.get('id', '')[:8]
        print(f'{state}|{name}|{provider}/{model}|{mode}|{aid}')
" 2>/dev/null || echo "ERROR")

    if [ "$agents_json" = "EMPTY" ]; then
        warn "没有已注册的 Agent"
    elif [ "$agents_json" = "ERROR" ]; then
        fail "解析 Agent 信息失败"
    else
        local running=0 idle=0 error=0 total=0
        while IFS='|' read -r state name model mode aid; do
            total=$((total + 1))
            case "$state" in
                Running) running=$((running + 1)); ok "${name} ${DIM}[${aid}]${NC} — ${GREEN}运行中${NC} (${model}) ${DIM}${mode}${NC}" ;;
                Idle)    idle=$((idle + 1));    info "${name} ${DIM}[${aid}]${NC} — ${CYAN}空闲${NC} (${model})" ;;
                Error*)  error=$((error + 1));  fail "${name} ${DIM}[${aid}]${NC} — ${RED}错误${NC} (${model})" ;;
                *)       info "${name} ${DIM}[${aid}]${NC} — ${state} (${model})" ;;
            esac
        done <<< "$agents_json"

        info "总计: ${total} 个Agent (${GREEN}${running}运行${NC} / ${CYAN}${idle}空闲${NC} / ${RED}${error}错误${NC})"
    fi

    json_set ".agents_raw" "$(echo "$status_resp" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin).get('agents',[])))" 2>/dev/null || echo "[]")"
    json_set ".default_model" "{\"provider\":\"$default_provider\",\"model\":\"$default_model\"}"
}

# ═══════════════════════════════════════════════════════════════════════
# 检查 4: Channel 适配器状态
# ═══════════════════════════════════════════════════════════════════════
check_channels() {
    header "Channel 通道状态"

    if [ -z "$BASE_URL" ]; then
        fail "无法获取 (守护进程未运行)"
        json_set ".channels" "[]"
        return
    fi

    local channels_resp
    channels_resp=$(api_get "/api/channels")
    if [ -z "$channels_resp" ]; then
        warn "通道端点无响应 (可能需要认证)"
        json_set ".channels" "[]"
        return
    fi

    local channels_info
    channels_info=$(echo "$channels_resp" | python3 -c "
import sys, json
data = json.load(sys.stdin)
channels = data if isinstance(data, list) else data.get('channels', [])
if not channels:
    print('EMPTY')
else:
    for ch in channels:
        name = ch.get('name', 'unknown')
        status = ch.get('status', ch.get('state', 'unknown'))
        connected = ch.get('connected', False)
        msg_count = ch.get('message_count', ch.get('messages_processed', 0))
        print(f'{name}|{status}|{connected}|{msg_count}')
" 2>/dev/null || echo "ERROR")

    if [ "$channels_info" = "EMPTY" ]; then
        info "没有配置的通道适配器"
        detail "配置通道: openfang channel setup"
    elif [ "$channels_info" = "ERROR" ]; then
        warn "无法解析通道信息"
    else
        local active=0 inactive=0
        while IFS='|' read -r name status connected msg_count; do
            if [ "$connected" = "True" ] || [ "$status" = "connected" ] || [ "$status" = "running" ]; then
                active=$((active + 1))
                ok "${name} — ${GREEN}已连接${NC} (${msg_count} 条消息)"
            else
                inactive=$((inactive + 1))
                warn "${name} — ${YELLOW}${status}${NC}"
            fi
        done <<< "$channels_info"

        info "总计: $((active + inactive)) 个通道 (${GREEN}${active}活跃${NC} / ${YELLOW}${inactive}未连接${NC})"
    fi

    json_set ".channels_raw" "$(echo "$channels_resp" 2>/dev/null || echo "[]")"
}

# ═══════════════════════════════════════════════════════════════════════
# 检查 5: Hands 状态
# ═══════════════════════════════════════════════════════════════════════
check_hands() {
    header "Hands 自主智能体"

    if [ -z "$BASE_URL" ]; then
        fail "无法获取 (守护进程未运行)"
        json_set ".hands" "[]"
        return
    fi

    # 可用的 Hands
    local hands_resp
    hands_resp=$(api_get "/api/hands")
    if [ -z "$hands_resp" ]; then
        warn "Hands 端点无响应 (可能需要认证)"
        json_set ".hands" "[]"
        return
    fi

    local hands_info
    hands_info=$(echo "$hands_resp" | python3 -c "
import sys, json
data = json.load(sys.stdin)
hands = data if isinstance(data, list) else data.get('hands', [])
if not hands:
    print('EMPTY')
else:
    for h in hands:
        name = h.get('name', h.get('id', 'unknown'))
        desc = h.get('description', '')[:40]
        print(f'{name}|{desc}')
" 2>/dev/null || echo "ERROR")

    if [ "$hands_info" != "EMPTY" ] && [ "$hands_info" != "ERROR" ]; then
        local hand_count=0
        while IFS='|' read -r name desc; do
            hand_count=$((hand_count + 1))
            detail "${name}: ${desc}"
        done <<< "$hands_info"
        info "可用 Hands: ${hand_count} 个"
    fi

    # 活跃实例
    local active_resp
    active_resp=$(api_get "/api/hands/active")
    if [ -n "$active_resp" ]; then
        local active_info
        active_info=$(echo "$active_resp" | python3 -c "
import sys, json
data = json.load(sys.stdin)
instances = data if isinstance(data, list) else data.get('instances', [])
if not instances:
    print('EMPTY')
else:
    for inst in instances:
        hand = inst.get('hand_id', inst.get('hand', 'unknown'))
        state = inst.get('state', inst.get('status', 'unknown'))
        iid = inst.get('id', '')[:8]
        print(f'{hand}|{state}|{iid}')
" 2>/dev/null || echo "EMPTY")

        if [ "$active_info" != "EMPTY" ]; then
            while IFS='|' read -r hand state iid; do
                case "$state" in
                    running|active)  ok "${hand} ${DIM}[${iid}]${NC} — ${GREEN}运行中${NC}" ;;
                    paused)          warn "${hand} ${DIM}[${iid}]${NC} — ${YELLOW}已暂停${NC}" ;;
                    *)               info "${hand} ${DIM}[${iid}]${NC} — ${state}" ;;
                esac
            done <<< "$active_info"
        else
            info "没有活跃的 Hand 实例"
        fi
    fi

    json_set ".hands_raw" "$(echo "$hands_resp" 2>/dev/null || echo "[]")"
}

# ═══════════════════════════════════════════════════════════════════════
# 检查 6: 集成/扩展健康
# ═══════════════════════════════════════════════════════════════════════
check_integrations() {
    header "集成 / 扩展 (MCP)"

    if [ -z "$BASE_URL" ]; then
        fail "无法获取 (守护进程未运行)"
        json_set ".integrations" "[]"
        return
    fi

    local integ_resp
    integ_resp=$(api_get "/api/integrations/health")
    if [ -z "$integ_resp" ]; then
        info "无集成健康数据 (可能需要认证或无已安装集成)"
        json_set ".integrations" "[]"
        return
    fi

    local integ_info
    integ_info=$(echo "$integ_resp" | python3 -c "
import sys, json
data = json.load(sys.stdin)
health = data.get('health', data) if isinstance(data, dict) else data
if not health or (isinstance(health, list) and len(health) == 0):
    print('EMPTY')
else:
    for h in (health if isinstance(health, list) else [health]):
        hid = h.get('id', 'unknown')
        status = h.get('status', 'unknown')
        tools = h.get('tool_count', 0)
        print(f'{hid}|{status}|{tools}')
" 2>/dev/null || echo "EMPTY")

    if [ "$integ_info" = "EMPTY" ]; then
        info "没有已安装的集成"
    else
        while IFS='|' read -r hid status tools; do
            case "$status" in
                ok|healthy|connected)  ok "${hid} — ${GREEN}健康${NC} (${tools} 个工具)" ;;
                degraded)              warn "${hid} — ${YELLOW}降级${NC} (${tools} 个工具)" ;;
                *)                     fail "${hid} — ${RED}${status}${NC} (${tools} 个工具)" ;;
            esac
        done <<< "$integ_info"
    fi

    # MCP 服务器
    local mcp_resp
    mcp_resp=$(api_get "/api/mcp/servers")
    if [ -n "$mcp_resp" ]; then
        local mcp_info
        mcp_info=$(echo "$mcp_resp" | python3 -c "
import sys, json
data = json.load(sys.stdin)
servers = data if isinstance(data, list) else data.get('servers', [])
if servers:
    for s in servers:
        name = s.get('name', 'unknown')
        status = s.get('status', s.get('state', 'unknown'))
        print(f'{name}|{status}')
else:
    print('EMPTY')
" 2>/dev/null || echo "EMPTY")

        if [ "$mcp_info" != "EMPTY" ]; then
            info "MCP 服务器:"
            while IFS='|' read -r name status; do
                case "$status" in
                    connected|running)  ok "  ${name} — ${GREEN}已连接${NC}" ;;
                    *)                  warn "  ${name} — ${status}" ;;
                esac
            done <<< "$mcp_info"
        fi
    fi

    json_set ".integrations_raw" "$(echo "$integ_resp" 2>/dev/null || echo "[]")"
}

# ═══════════════════════════════════════════════════════════════════════
# 检查 7: P2P 网络状态
# ═══════════════════════════════════════════════════════════════════════
check_network() {
    header "P2P 网络 (OFP)"

    if [ -z "$BASE_URL" ]; then
        fail "无法获取 (守护进程未运行)"
        json_set ".network" "{\"status\":\"unavailable\"}"
        return
    fi

    local net_resp
    net_resp=$(api_get "/api/network/status")
    if [ -z "$net_resp" ]; then
        info "P2P 网络未启用或无响应"
        json_set ".network" "{\"status\":\"disabled\"}"
        return
    fi

    local net_enabled
    net_enabled=$(echo "$net_resp" | python3 -c "
import sys, json
data = json.load(sys.stdin)
enabled = data.get('enabled', data.get('network_enabled', False))
peers = data.get('peer_count', data.get('peers', 0))
print(f'{enabled}|{peers}')
" 2>/dev/null || echo "False|0")

    IFS='|' read -r enabled peers <<< "$net_enabled"
    if [ "$enabled" = "True" ] || [ "$enabled" = "true" ]; then
        ok "OFP 网络已启用 (${peers} 个对等节点)"
    else
        info "OFP 网络未启用"
        detail "启用: 在 config.toml 中设置 network_enabled = true"
    fi

    json_set ".network" "{\"enabled\":$enabled,\"peers\":$peers}"
}

# ═══════════════════════════════════════════════════════════════════════
# 检查 8: Prometheus 指标摘要
# ═══════════════════════════════════════════════════════════════════════
check_metrics() {
    header "Prometheus 指标摘要"

    if [ -z "$BASE_URL" ]; then
        fail "无法获取 (守护进程未运行)"
        return
    fi

    local metrics_resp
    metrics_resp=$(api_get "/api/metrics")
    if [ -z "$metrics_resp" ]; then
        warn "指标端点无响应"
        return
    fi

    # 解析关键指标
    local uptime agents_active agents_total tokens tools panics restarts
    uptime=$(echo "$metrics_resp" | grep "^openfang_uptime_seconds " | awk '{print $2}' || echo "0")
    agents_active=$(echo "$metrics_resp" | grep "^openfang_agents_active " | awk '{print $2}' || echo "0")
    agents_total=$(echo "$metrics_resp" | grep "^openfang_agents_total " | awk '{print $2}' || echo "0")
    panics=$(echo "$metrics_resp" | grep "^openfang_panics_total " | awk '{print $2}' || echo "0")
    restarts=$(echo "$metrics_resp" | grep "^openfang_restarts_total " | awk '{print $2}' || echo "0")

    info "活跃/总计 Agent: ${agents_active}/${agents_total}"
    info "Panic/重启: ${panics}/${restarts}"

    # 每个 agent 的 token 使用量
    if [ "$VERBOSE" = true ]; then
        local token_lines
        token_lines=$(echo "$metrics_resp" | grep "^openfang_tokens_total{" || true)
        if [ -n "$token_lines" ]; then
            info "Token 使用 (滚动小时窗口):"
            echo "$token_lines" | while read -r line; do
                local agent_name tokens_val
                agent_name=$(echo "$line" | sed 's/.*agent="\([^"]*\)".*/\1/')
                tokens_val=$(echo "$line" | awk '{print $2}')
                detail "  ${agent_name}: ${tokens_val} tokens"
            done
        fi
    fi

    json_set ".metrics" "{\"uptime\":$uptime,\"agents_active\":$agents_active,\"agents_total\":$agents_total,\"panics\":$panics,\"restarts\":$restarts}"
}

# ═══════════════════════════════════════════════════════════════════════
# 检查 9: 系统资源
# ═══════════════════════════════════════════════════════════════════════
check_resources() {
    header "系统资源"

    # 磁盘使用
    local db_path="$OPENFANG_HOME/data/openfang.db"
    if [ -f "$db_path" ]; then
        local db_size
        db_size=$(du -sh "$db_path" 2>/dev/null | awk '{print $1}')
        ok "数据库: ${db_path} (${db_size})"
    else
        info "数据库文件不存在: ${db_path}"
    fi

    # openfang home 目录大小
    if [ -d "$OPENFANG_HOME" ]; then
        local home_size
        home_size=$(du -sh "$OPENFANG_HOME" 2>/dev/null | awk '{print $1}')
        info "数据目录: ${OPENFANG_HOME} (${home_size})"
    fi

    # release 二进制大小
    local release_bin="$PROJECT_DIR/target/release/openfang"
    if [ -f "$release_bin" ]; then
        local bin_size
        bin_size=$(du -sh "$release_bin" 2>/dev/null | awk '{print $1}')
        info "Release 二进制: ${bin_size}"
    fi

    # 系统内存
    if command -v free &>/dev/null; then
        local mem_info
        mem_info=$(free -h | grep Mem)
        local total used avail
        total=$(echo "$mem_info" | awk '{print $2}')
        used=$(echo "$mem_info" | awk '{print $3}')
        avail=$(echo "$mem_info" | awk '{print $7}')
        info "系统内存: ${used} 已用 / ${total} 总计 (${avail} 可用)"
    fi

    # 日志文件
    local log_file="/tmp/openfang-daemon.log"
    if [ -f "$log_file" ]; then
        local log_size
        log_size=$(du -sh "$log_file" 2>/dev/null | awk '{print $1}')
        info "守护进程日志: ${log_file} (${log_size})"

        # 最近错误
        local recent_errors
        recent_errors=$(grep -ci "error\|panic\|fatal" "$log_file" 2>/dev/null || echo "0")
        if [ "$recent_errors" -gt 0 ]; then
            warn "日志中有 ${recent_errors} 条错误/panic/fatal 记录"
            if [ "$VERBOSE" = true ]; then
                detail "最近 3 条错误:"
                grep -i "error\|panic\|fatal" "$log_file" 2>/dev/null | tail -3 | while read -r line; do
                    detail "  $line"
                done
            fi
        fi
    fi

    json_set ".resources" "{\"openfang_home\":\"$OPENFANG_HOME\",\"database\":\"$db_path\"}"
}

# ═══════════════════════════════════════════════════════════════════════
# 检查 10: 配置
# ═══════════════════════════════════════════════════════════════════════
check_config() {
    header "配置"

    local config_file="$OPENFANG_HOME/config.toml"
    if [ -f "$config_file" ]; then
        ok "配置文件: ${config_file}"

        # 检查关键配置
        local api_listen
        api_listen=$(grep "^api_listen" "$config_file" 2>/dev/null | head -1 | sed 's/.*=\s*"\(.*\)"/\1/' || true)
        if [ -n "$api_listen" ]; then
            info "API 监听: ${api_listen}"
        fi

        # 检查 API Key
        local has_api_key
        has_api_key=$(grep "^api_key\s*=" "$config_file" 2>/dev/null | grep -v '""' | grep -v "^#" || true)
        if [ -n "$has_api_key" ]; then
            ok "API 认证: 已配置"
        else
            warn "API 认证: 未配置 (建议设置 api_key)"
        fi
    else
        warn "配置文件不存在: ${config_file}"
        detail "初始化: openfang init"
    fi

    # 检查 .env 文件中的 API Keys
    local env_file="$OPENFANG_HOME/.env"
    if [ -f "$env_file" ]; then
        local key_count
        key_count=$(grep -c ".*_KEY=\|.*_TOKEN=" "$env_file" 2>/dev/null || echo "0")
        info "环境变量文件: ${env_file} (${key_count} 个 key/token)"
    fi

    json_set ".config" "{\"file\":\"$config_file\",\"exists\":$([ -f "$config_file" ] && echo true || echo false)}"
}

# ═══════════════════════════════════════════════════════════════════════
# 主函数
# ═══════════════════════════════════════════════════════════════════════
main() {
    if [ "$JSON_MODE" = false ]; then
        echo ""
        echo -e "${BOLD}${CYAN}  🐍 OpenFang 状态检查${NC}"
        echo -e "${DIM}  $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    fi

    json_set ".timestamp" "$(date -Iseconds)"
    json_set ".check_version" "1.0.0"

    check_gateway
    check_health
    check_agents
    check_channels
    check_hands
    check_integrations
    check_network

    if [ "$VERBOSE" = true ]; then
        check_metrics
    fi

    check_resources
    check_config

    # ── 总结 ────────────────────────────────────────────────────────
    if [ "$JSON_MODE" = false ]; then
        header "检查完成"

        if [ -n "$BASE_URL" ]; then
            local health_resp
            health_resp=$(api_get "/api/health")
            local health_status
            health_status=$(echo "$health_resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null || echo "unknown")

            if [ "$health_status" = "ok" ]; then
                echo -e "\n  ${GREEN}${BOLD}🟢 OpenFang 运行正常${NC}"
            elif [ "$health_status" = "degraded" ]; then
                echo -e "\n  ${YELLOW}${BOLD}🟡 OpenFang 运行中 (部分降级)${NC}"
            else
                echo -e "\n  ${RED}${BOLD}🔴 OpenFang 异常${NC}"
            fi

            echo -e "  ${DIM}仪表板: ${BASE_URL}/${NC}"
        else
            echo -e "\n  ${RED}${BOLD}⭕ OpenFang 未运行${NC}"
            echo -e "  ${DIM}启动: openfang start 或 ./scripts/start.sh${NC}"
        fi
        echo ""
    fi

    # ── JSON 输出 ────────────────────────────────────────────────────
    if [ "$JSON_MODE" = true ]; then
        echo "$JSON_RESULT" | python3 -m json.tool 2>/dev/null || echo "$JSON_RESULT"
    fi
}

main
