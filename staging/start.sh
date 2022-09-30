#!/bin/bash
ROOT_DIR=$(dirname $(realpath $0))
export network_number=[[NETWORK_NUMBER]]
source $ROOT_DIR/base.sh
source $ROOT_DIR/envs/.env
export ENV_DIR=$ROOT_DIR

$ROOT_DIR/start_core.sh
sleep 30
#docker exec mbr_db_$network_number bash -c 'bash /docker-entrypoint-initdb.d/1_init.sh'
docker exec mbr_portal_api_$network_number bash -c 'cd /app; npm run dbm:init'
docker exec mbr_db_$network_number bash -c 'bash /docker-entrypoint-initdb.d/3_init_user.sh'
docker exec mbr_db_$network_number bash -c 'bash /docker-entrypoint-initdb.d/2_clean_node.sh'

$ROOT_DIR/start_stat.sh
