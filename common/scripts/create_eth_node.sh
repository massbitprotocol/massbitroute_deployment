#!/bin/bash
ROOT_DIR=$(dirname $(realpath $0))
export ENV_DIR=$ROOT_DIR
source $ROOT_DIR/../envs/.env
export COUNTER_NODE=1
bash -x $ROOT_DIR/../scenarios/000_init.sh
bash -x $ROOT_DIR/../scenarios/001_create_eth_node.sh
