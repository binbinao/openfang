# OpenFang 脚本使用说明

本目录包含用于管理OpenFang服务的各种脚本。

## 可用脚本

### 1. `start.sh` - 启动脚本
**功能**: 启动OpenFang守护进程
**用法**:
```bash
./scripts/start.sh          # 启动服务
./scripts/start.sh --status  # 只显示状态
./scripts/start.sh --help    # 显示帮助信息
```

### 2. `restart-simple.sh` - 简化重启脚本
**功能**: 提供简化的重启接口，包装现有restart.sh的功能
**用法**:
```bash
./scripts/restart-simple.sh          # 普通重启
./scripts/restart-simple.sh --build   # 重新构建(debug)并重启
./scripts/restart-simple.sh --release # 重新构建(release)并重启
./scripts/restart-simple.sh --help    # 显示帮助信息
```

### 3. `restart.sh` - 完整重启脚本（已存在）
**功能**: 完整的重启功能，支持多种模式
**用法**:
```bash
./scripts/restart.sh          # 重启
./scripts/restart.sh build     # 重新构建(debug)并重启
./scripts/restart.sh release  # 重新构建(release)并重启
./scripts/restart.sh status    # 显示状态
./scripts/restart.sh stop      # 停止服务
./scripts/restart.sh start     # 启动服务
```

### 4. `check-env.sh` - 环境检查脚本
**功能**: 检查OpenFang运行所需的环境依赖
**用法**:
```bash
./scripts/check-env.sh        # 检查环境
./scripts/check-env.sh --help # 显示帮助信息
```

### 5. `install.sh` - 安装脚本（已存在）
**功能**: 系统安装脚本

### 6. `install.ps1` - Windows安装脚本（已存在）
**功能**: Windows系统安装脚本

## 使用示例

### 启动服务
```bash
cd /data/workspace/openfang
./scripts/start.sh
```

### 检查服务状态
```bash
./scripts/start.sh --status
# 或者
./scripts/restart.sh status
```

### 重启服务
```bash
# 简单重启
./scripts/restart-simple.sh

# 重新构建并重启
./scripts/restart-simple.sh --build
```

### 检查环境
```bash
./scripts/check-env.sh
```

## 服务信息

- **API地址**: http://127.0.0.1:4200
- **管理界面**: http://127.0.0.1:4200/
- **默认端口**: 4200
- **数据目录**: 由配置决定

## 注意事项

1. 所有脚本都需要执行权限，如果遇到权限问题，请运行：
   ```bash
   chmod +x scripts/*.sh
   ```

2. 启动脚本会自动检查服务是否已在运行，避免重复启动

3. 重启脚本会先停止服务再启动，确保服务完全重启

4. 环境检查脚本会验证Rust工具链和openfang二进制文件是否可用