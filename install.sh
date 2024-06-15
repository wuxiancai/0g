#!/bin/bash

# 更新并安装依赖项
echo "安装依赖。。。"
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y curl wget jq unzip lz4 make

#设置时间为utc
timedatectl set-timezone UTC

#安装go1.22.4
wget https://golang.org/dl/go1.22.4.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.22.4.linux-amd64.tar.gz
sed -i '$ a export PATH=$PATH:/usr/local/go/bin' ~/.bashrc; source ~/.bashrc
go version
rm -rf go1.22.4.linux-amd64.tar.gz

# 下载节点二进制文件
echo '下载0gchaind'
git clone -b v0.1.0 https://github.com/0glabs/0g-chain.git
./0g-chain/networks/testnet/install.sh
source .profile
0gchaind --help

#Set Chain ID
echo "Set Chain ID"
0gchaind config chain-id zgtendermint_16600-1

#初始化节点
echo "请输入0g节点的名字："
read nodename
0gchaind init $nodename --chain-id zgtendermint_16600-1

#删除创世文件
rm ~/.0gchain/config/genesis.json

# 下载并配置配置文件
echo "Downloading configuration file..."
wget -P ~/.0gchain/config https://github.com/0glabs/0g-chain/releases/download/v0.1.0/genesis.json

sed -i '/seeds =/c\seeds = "c4d619f6088cb0b24b4ab43a0510bf9251ab5d7f@54.241.167.190:26656,44d11d4ba92a01b520923f51632d2450984d5886@54.176.175.48:26656,f2693dd86766b5bf8fd6ab87e2e970d564d20aff@54.193.250.204:26656,f878d40c538c8c23653a5b70f615f8dccec6fb9f@54.215.187.94:26656"' /root/.0gchain/config/config.toml
sed -i '/persistent_peers =/c\persistent_peers = "c4d619f6088cb0b24b4ab43a0510bf9251ab5d7f@54.241.167.190:26656,44d11d4ba92a01b520923f51632d2450984d5886@54.176.175.48:26656,f2693dd86766b5bf8fd6ab87e2e970d564d20aff@54.193.250.204:26656,f878d40c538c8c23653a5b70f615f8dccec6fb9f@54.215.187.94:26656"' /root/.0gchain/config/config.toml

# 验证genesis文件
echo "Validating genesis file..."
0gchaind validate-genesis

# 设置种子节点
echo "Setting up seed nodes..."
SEEDS="c4d619f6088cb0b24b4ab43a0510bf9251ab5d7f@54.241.167.190:26656,44d11d4ba92a01b520923f51632d2450984d5886@54.176.175.48:26656,f2693dd86766b5bf8fd6ab87e2e970d564d20aff@54.193.250.204:26656,f878d40c538c8c23653a5b70f615f8dccec6fb9f@18.166.164.232:26656"
sed -i -e "s/^seeds *=.*/seeds = \"$SEEDS\"/" $NODE_DIR/config/config.toml

#添加系统服务
tee /etc/systemd/system/0gchaind.service > /dev/null <<EOF
[Unit]
Description=0G Node
After=network.target

[Service]
User=root
ExecStart=/root/go/bin/0gchaind start
Restart=always
RestartSec=3
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
source .profile
#启动服务
systemctl daemon-reload
systemctl enable 0gchaind
systemctl start 0gchaind

#查看同步状态
echo "请使用screen -S NODE,查看同步状态！"
echo '查看命令是： journalctl -fu 0gchaind'


#创建钱包
echo "如果没有钱包，请创建钱包，如果有钱包，也可以导入钱包。"
echo '创建钱包请输入：1，导入钱包请输入：2'
read create
if [ $create -eq "1" ];then
echo "请输入钱包名称："
read wallet
0gchaind keys add $wallet --eth
echo "请记录好钱包地址及助记词！"
else
echo "请输入钱包的密钥："
read pri_key
0gchaind keys import $pri_key
fi
echo "请去这个地址领水:faucet.0g.ai"
source .profile
echo '把0g地址变为eth地址命令: 0gchaind debug addr '
:<<EOF
# 生成新的验证者账户
echo "请输入验证者名字："
read validatorname
echo "请输入钱包名称："
read WALLET
0gchaind tx staking create-validator \
  --amount=1000000ua0gi \
  --pubkey=$(0gchaind tendermint show-validator) \
  --moniker=$validatorname \
  --chain-id=$CHAIN_ID \
  --commission-rate="0.10" \
  --commission-max-rate="0.20" \
  --commission-max-change-rate="0.01" \
  --min-self-delegation="1" \
  --from=$WALLET \
  --gas=auto \
  --gas-adjustment=1.4 \
  --fees=5000ua0gi \
  --yes

echo "Validator node setup complete."
EOF