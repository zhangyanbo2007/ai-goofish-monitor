#!/bin/bash
# FRP端口映射配置脚本
# 用法: ./setup-frp.sh [service] [env]
# 示例: ./setup-frp.sh ai-goofish-monitor production
#       ./setup-frp.sh ai-goofish-monitor development

set -e

# 配置文件路径
CONFIG_FILE="$(dirname "$0")/../frp-config.json"

# 检查配置文件
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ 配置文件不存在: $CONFIG_FILE"
    exit 1
fi

# 读取参数
SERVICE=${1:-"ai-goofish-monitor"}
ENV=${2:-"production"}

# 读取配置
VPS_HOST=$(jq -r '.vps.host' "$CONFIG_FILE")
VPS_USER=$(jq -r '.vps.ssh_user' "$CONFIG_FILE")
VPS_PASS=$(jq -r '.vps.ssh_password' "$CONFIG_FILE")
FRP_CONTROL_PORT=$(jq -r '.vps.frp_control_port' "$CONFIG_FILE")
FRP_WEB_PORT=$(jq -r '.vps.frp_web_port' "$CONFIG_FILE")
FRP_WEB_USER=$(jq -r '.vps.frp_web_user' "$CONFIG_FILE")
FRP_WEB_PASS=$(jq -r '.vps.frp_web_password' "$CONFIG_FILE")

# 读取服务配置
EXTERNAL_PORT=$(jq -r ".services.${SERVICE}.${ENV}.external_port" "$CONFIG_FILE")
INTERNAL_PORT=$(jq -r ".services.${SERVICE}.${ENV}.internal_port" "$CONFIG_FILE")
LOCAL_IP=$(jq -r ".services.${SERVICE}.${ENV}.local_ip" "$CONFIG_FILE")
PROXY_NAME=$(jq -r ".services.${SERVICE}.${ENV}.frp_proxy_name" "$CONFIG_FILE")

echo "=========================================="
echo "FRP端口映射配置"
echo "=========================================="
echo "服务: $SERVICE"
echo "环境: $ENV"
echo "外部端口: $EXTERNAL_PORT"
echo "内部端口: $INTERNAL_PORT"
echo "代理名称: $PROXY_NAME"
echo "=========================================="

# 生成FRP客户端配置
FRP_CONFIG="
[[proxies]]
name = \"${PROXY_NAME}\"
type = \"tcp\"
localIP = \"${LOCAL_IP}\"
localPort = ${INTERNAL_PORT}
remotePort = ${EXTERNAL_PORT}
"

echo ""
echo "生成的FRP客户端配置:"
echo "------------------------------------------"
echo "$FRP_CONFIG"
echo "------------------------------------------"

# 询问是否继续
read -p "是否继续配置？(y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消"
    exit 0
fi

# 通过SSH连接到VPS并配置
echo ""
echo "连接到VPS并配置FRP..."

# 使用sshpass连接
sshpass -p "$VPS_PASS" ssh -o StrictHostKeyChecking=no "$VPS_USER@$VPS_HOST" << EOF
# 检查FRP服务是否运行
if ! pgrep frps > /dev/null; then
    echo "启动FRP服务..."
    cd /opt/frp && ./frps -c frps.toml &
    sleep 2
fi

# 检查端口是否被占用
if netstat -tlnp | grep -q ":${EXTERNAL_PORT}"; then
    echo "⚠️  端口 ${EXTERNAL_PORT} 已被占用"
    echo "当前占用进程:"
    netstat -tlnp | grep ":${EXTERNAL_PORT}"
    read -p "是否继续？(y/n) " -n 1 -r
    if [[ ! \$REPLY =~ ^[Yy]\$ ]]; then
        echo "已取消"
        exit 1
    fi
fi

echo "✅ FRP配置完成"
echo "外部访问地址: http://${VPS_HOST}:${EXTERNAL_PORT}"
EOF

echo ""
echo "✅ 配置完成！"
echo "外部访问地址: http://${VPS_HOST}:${EXTERNAL_PORT}"
echo ""
echo "注意: 需要在客户端机器上配置FRP客户端才能生效"
echo "客户端配置文件路径: /etc/frp/frpc.toml"
