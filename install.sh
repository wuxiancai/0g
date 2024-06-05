#!/bin/bash

# 设置变量
NODE_DIR="$HOME/.0gchain"
BINARY_URL="https://github.com/0glabs/0g-chain/releases/download/v0.1.0/0gchaind"
CONFIG_URL="https://github.com/0glabs/0g-chain/releases/download/v0.1.0/config.toml"
GENESIS_URL="https://github.com/0glabs/0g-chain/releases/download/v0.1.0/genesis.json"
SERVICE_NAME="0gchaind.service"
VALIDATOR_NAME="your_validator_name"  # 替换为实际的验证者名称
CHAIN_ID="zgtendermint_16600-1"

# 更新并安装依赖项
echo "Updating system and installing dependencies..."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y curl wget jq unzip

# 创建节点目录
echo "Creating directory for the node..."
mkdir -p $NODE_DIR
cd $NODE_DIR

# 下载节点二进制文件
echo "Downloading node binary..."
wget $BINARY_URL -O 0gchaind
chmod +x 0gchaind
sudo mv 0gchaind /usr/local/bin/

# 下载并配置配置文件
echo "Downloading configuration file..."
wget $CONFIG_URL -O config.toml
wget $GENESIS_URL -O genesis.json
cp config.toml $NODE_DIR/config.toml
cp genesis.json $NODE_DIR/config/genesis.json

# 初始化节点
echo "Initializing the node..."
0gchaind init $VALIDATOR_NAME --chain-id $CHAIN_ID

# 验证genesis文件
echo "Validating genesis file..."
0gchaind validate-genesis

# 设置种子节点
echo "Setting up seed nodes..."
SEEDS="c4d619f6088cb0b24b4ab43a0510bf9251ab5d7f@54.241.167.190:26656,44d11d4ba92a01b520923f51632d2450984d5886@54.176.175.48:26656,f2693dd86766b5bf8fd6ab87e2e970d564d20aff@54.193.250.204:26656,f878d40c538c8c23653a5b70f615f8dccec6fb9f@18.166.164.232:26656"
sed -i -e "s/^seeds *=.*/seeds = \"$SEEDS\"/" $NODE_DIR/config/config.toml

# 创建验证者密钥
echo "Creating validator key..."
0gchaind keys add $VALIDATOR_NAME --keyring-backend test --output json > validator-key.json

# 获取验证者地址
VALIDATOR_ADDRESS=$(jq -r .address validator-key.json)

# 生成新的验证者账户
echo "Generating new validator account..."
0gchaind tx staking create-validator \
  --amount=1000000ua0gi \
  --pubkey=$(0gchaind tendermint show-validator) \
  --moniker=$VALIDATOR_NAME \
  --chain-id=$CHAIN_ID \
  --commission-rate="0.10" \
  --commission-max-rate="0.20" \
  --commission-max-change-rate="0.01" \
  --min-self-delegation="1" \
  --from=$VALIDATOR_NAME \
  --gas=auto \
  --gas-adjustment=1.4 \
  --fees=5000ua0gi \
  --yes

# 创建systemd服务文件
echo "Creating systemd service file..."
sudo bash -c "cat > /etc/systemd/system/$SERVICE_NAME" << EOL
[Unit]
Description=0G Validator Node
After=network-online.target

[Service]
User=$USER
WorkingDirectory=$NODE_DIR
ExecStart=/usr/local/bin/0gchaind start --home $NODE_DIR
Restart=always
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOL

# 重新加载systemd并启动服务
echo "Reloading systemd and starting the validator node service..."
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME

echo "Validator node setup complete."
