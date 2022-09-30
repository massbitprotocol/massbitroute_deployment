#!/bin/bash
ROOT_DIR=$(realpath $(dirname $(realpath $0)))
source $ROOT_DIR/../base.sh
SCENARIO_ID="$(echo $RANDOM | md5sum | head -c 5)"
echo "-------------------------------------------------------";
echo "Run scenario ${BASH_SOURCE[0]} with ID $SCENARIO_ID----";
echo "-------------------------------------------------------";

blockchain=eth
network=mainnet
PUBLIC_API="https://main-light.eth.linkpool.io"
docker exec mbr_proxy_$network_number /test/scripts/test_main_flow.sh _login
docker exec mbr_proxy_$network_number /test/scripts/test_dapi.sh _init_params --scenario=$SCENARIO_ID --blockchain=$blockchain --network=$network
docker exec mbr_proxy_$network_number /test/scripts/test_dapi.sh _create_project $blockchain $network

docker exec mbr_proxy_$network_number /test/scripts/test_dapi.sh _create_dapi $blockchain $network

#Execute block chain testing
docker exec mbr_proxy_$network_number /test/scripts/test_dapi.sh _execute_apis_testing $blockchain $network $PUBLIC_API
