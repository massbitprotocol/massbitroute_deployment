#!/bin/bash
TEST_USERNAME=demo
TEST_PASSWORD=Codelight123
TEST_WALLET_ADDRESS=5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY
protocol=http
dataSource=$DATASOURCE
dataSourceWs=$DATASOURCE_WS
domain=${DOMAIN:-massbitroute.net}
nodePrefix="$(echo $RANDOM | md5sum | head -c 5)"
projectPrefix="$(echo $RANDOM | md5sum | head -c 5)"
MEMONIC="bottom drive obey lake curtain smoke basket hold race lonely fit walk//Alice"
PROVIDER_STATUS_TIMEOUT=150
declare -A blockchains=()
blockchains["eth"]="mainnet rinkerby"
blockchains["dot"]="mainnet"
declare -A dataSources=()
dataSources["eth"]="http://34.81.232.186:8545 ws://34.81.232.186:8546"
dataSources["dot"]="https://34.87.170.136 wss://34.87.170.136/websocket"
STAKING_AMOUNT_PROJECT=1
#echo "All blockchains : ${blockchains[*]}"
#for key in ${!blockchains[@]}
#do
#    networks=(${blockchains[$key]});
#    for n in ${networks[@]}
#    do
#      echo "$key:$n"
#    done
#    #echo ${networks[@]}
#    #echo "["$key"]:["${blockchains[$key]}"]"
#done

export blockchains
export dataSources
#export TEST_MODE=${TEST_MODE:-debug}
export TEST_MODE=test
