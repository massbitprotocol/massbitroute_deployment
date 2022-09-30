#!/bin/bash
ROOT_DIR=$(realpath $(dirname $(realpath $0)))
source $ROOT_DIR/../base.sh
docker exec mbr_proxy_$network_number /test/scripts/test_main_flow.sh _login
