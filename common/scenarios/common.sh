#!/bin/bash

#-------------------------------------------
# $1 - DockerId, $2 - providerType, $3 - providerId
#-------------------------------------------
_destroy_provider() {
  DOCKER_ID=$1
  PROVIDER_TYPE="${2,,}"
  PROVIDER_ID=$3
  if [ "$PROVIDER_TYPE" == "node" ]; then
    docker-compose -f $ENV_DIR/node-docker-compose-${DOCKER_ID}.yaml down
    docker exec mbr_proxy_$network_number /test/scripts/test_main_flow.sh _check_provider_status node investigate $PROVIDER_ID
  else
    docker-compose -f $ENV_DIR/gateway-docker-compose-${DOCKER_ID}.yaml down
    docker exec mbr_proxy_$network_number /test/scripts/test_main_flow.sh _check_provider_status gateway investigate $PROVIDER_ID
  fi
  status=$(cat $ENV_DIR/proxy/vars/status/$PROVIDER_ID)
  if [ "$status" != "investigate" ]; then
    echo "Status of $PROVIDER_TYPE $PROVIDER_ID is not changed to investigate. Test failed";
    exit 1
  fi
}

$@
