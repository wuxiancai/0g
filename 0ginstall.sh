#!/bin/bash


function install() {
# 安装需要的包
sudo apt update && sudo apt install curl git jq build-essential gcc unzip wget lz4 -y

# 检查 go 是否已安装
cd $HOME && \
ver="1.21.3" && \
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz" && \
sudo rm -rf /usr/local/go && \
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz" && \
rm "go$ver.linux-amd64.tar.gz" && \
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> ~/.bash_profile && \
source ~/.bash_profile && \
go version

# 构建evmosd二进制文件
git clone https://github.com/0glabs/0g-evmos.git
cd 0g-evmos
git checkout v1.0.0-testnet
make install
evmosd version

# 设置变量
echo 'export MONIKER="My_Node"' >> ~/.bash_profile
echo 'export CHAIN_ID="zgtendermint_9000-1"' >> ~/.bash_profile
echo 'export WALLET_NAME="wallet"' >> ~/.bash_profile
echo 'export RPC_PORT="26657"' >> ~/.bash_profile
source $HOME/.bash_profile

# 初始化节点
cd $HOME
evmosd init $MONIKER --chain-id $CHAIN_ID
evmosd config chain-id $CHAIN_ID
evmosd config node tcp://localhost:$RPC_PORT
evmosd config keyring-backend os # You can set it to "test" so you will not be asked for a password

# 下载genesis.json
wget https://github.com/0glabs/0g-evmos/releases/download/v1.0.0-testnet/genesis.json -O $HOME/.evmosd/config/genesis.json

# 将种子和对等点添加到 config.toml
PEERS="1248487ea585730cdf5d3c32e0c2a43ad0cda973@peer-zero-gravity-testnet.trusted-point.com:26326" && \
SEEDS="8c01665f88896bca44e8902a30e4278bed08033f@54.241.167.190:26656,b288e8b37f4b0dbd9a03e8ce926cd9c801aacf27@54.176.175.48:26656,8e20e8e88d504e67c7a3a58c2ea31d965aa2a890@54.193.250.204:26656,e50ac888b35175bfd4f999697bdeb5b7b52bfc06@54.215.187.94:26656" && \
sed -i -e "s/^seeds *=.*/seeds = \"$SEEDS\"/; s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.evmosd/config/config.toml

# 设置最低 Gas 价格
sed -i "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0.00252aevmos\"/" $HOME/.evmosd/config/app.toml

# 创建服务文件
sudo tee /etc/systemd/system/ogd.service > /dev/null <<EOF
[Unit]
Description=OG Node
After=network.target

[Service]
User=$USER
Type=simple
ExecStart=$(which evmosd) start --home $HOME/.evmosd
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# 启动节点
sudo systemctl daemon-reload && \
sudo systemctl enable ogd && \
sudo systemctl restart ogd && \
sudo journalctl -u ogd -f -o cat

}

# 创建钱包
function create_wallet() {
    read -p "请输入钱包名称: " WALLET_NAME
    evmosd keys add $WALLET_NAME
}

# 提取十六进制地址以向水龙头请求一些代币
function get_address() {
    read -p "请输入钱包名称: " WALLET_NAME
    echo "0x$(/root/go/bin/evmosd debug addr $(/root/go/bin/evmosd keys show $WALLET_NAME -a) | grep hex | awk '{print $3}')"
}

# 查看余额
function get_balance() {
    read -p "请输入钱包名称: " WALLET_NAME
    evmosd q bank balances $(evmosd keys show $WALLET_NAME -a) 
}

#查看验证器状态
function get_status() {
    evmosd status | jq .SyncInfo
}

# 重启节点
function restart() {
    sudo systemctl restart ogd && sudo journalctl -u ogd -f -o cat
}

# 查看日志
function get_logs() {
    sudo journalctl -u ogd -f -o cat
}

# 停止节点
function stop() {
    sudo systemctl stop ogd
}


# 删除节点
function delete_node() {
    sudo systemctl stop ogd
    sudo systemctl disable ogd
    sudo rm /etc/systemd/system/ogd.service
    rm -rf $HOME/.evmosd $HOME/0g-evmos
}

# 主菜单
function main_menu() {
	echo "请选择要执行的操作:"
    echo "1. 安装并启动节点"
    echo "2. 创建钱包"
    echo "3. 获取地址（16进制地址）"
    echo "4. 查看余额"
    echo "5. 查看验证器状态"
    echo "6. 重启节点"
    echo "7. 查看日志"
    echo "8. 停止节点"
    read -p "请输入选项（1-8）: " OPTION

    case $OPTION in
    1) install ;;
    2) create_wallet ;;
    3) get_address ;;
    4) get_balance ;;
    5) get_status ;;
    6) restart ;;
    7) get_logs ;;
    8) stop ;;
    *) echo "无效选项。" ;;
    esac
}

# 显示主菜单
main_menu
