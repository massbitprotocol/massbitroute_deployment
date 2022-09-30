#!/bin/bash
ROOT_DIR=$(dirname $(realpath $0))
export ENV_DIR=$ROOT_DIR
source $ROOT_DIR/../envs/.env
export COUNTER_GATEWAY=1
bash -x $ROOT_DIR/../scenarios/000_init.sh
bash -x $ROOT_DIR/../scenarios/002_create_eth_gateway.sh
