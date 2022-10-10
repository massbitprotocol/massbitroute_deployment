#!/bin/bash
export RUNTIME_DIR=/home/huy/work/test_runtime
export network_prefix=mbr_test_network
export network_name=${network_prefix}_$network_number
export ENV_DIR=$RUNTIME_DIR/$network_number
export domain=massbitroute.net
export PROTOCOL=http
#IPs
export PROXY_IP=254
export TEST_CLIENT_IP=253
export CHAIN_IP=20
export PORTAL_IP=10
export WEB_IP=11
export STAKING_IP=12
export POSTGRES_IP=13
export REDIS_IP=14
export FISHERMAN_SCHEDULER_IP=15
export FISHERMAN_WORKER01_IP=16
export FISHERMAN_WORKER02_IP=17
export GWMAN_IP=2
export GIT_IP=5
export API_IP=6
export SESSION_IP=7

export START_IP=20

export GIT_PRIVATE_BRANCH=shamu
export MASSBIT_ROUTE_SID=403716b0f58a7d6ddec769f8ca6008f2c1c0cea6
export MASSBIT_ROUTE_PARTNER_ID=fc78b64c5c33f3f270700b0c4d3e7998188035ab
export FISHERMAN_ENVIRONMENT=docker-test
declare -A blockchains=()
blockchains["eth"]="mainnet rinkerby"
blockchains["dot"]="mainnet"
export blockchains
