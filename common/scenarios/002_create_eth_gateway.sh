#!/bin/bash
ROOT_DIR=$(realpath $(dirname $(realpath $0)))
source $ROOT_DIR/../base.sh
echo '-------------------------------------------'
echo "Run scenario ${BASH_SOURCE[0]}---------"
echo '-------------------------------------------'
blockchain=eth
network=mainnet
zone=AS
USER_ID=$(cat $ENV_DIR/proxy/vars/USER_ID)
LOOP=${COUNTER_GATEWAY:-1}
for (( k = 0; k<$LOOP; k++ )); do
  DOCKER_ID=$(echo $RANDOM | md5sum | head -c 5)
  printf "Create gateway with docker ID %s\n" $DOCKER_ID
  #State5: Create gateway
  docker exec mbr_proxy_$network_number /test/scripts/test_main_flow.sh _create_gateway $blockchain $network $DOCKER_ID
  GATEWAY_ID=$(cat $ENV_DIR/proxy/vars/${DOCKER_ID}/GATEWAY_ID)
  GATEWAY_APP_KEY=$(cat $ENV_DIR/proxy/vars/${DOCKER_ID}/GATEWAY_APP_KEY)
  if [ "$GATEWAY_ID" == "null" ]; then
    echo 'Test failed'
    exit 1
  fi
  cat $ENV_DIR/templates/gateway-docker-compose.yaml.template | \
    sed "s/\[\[USER_ID\]\]/$USER_ID/g" | \
  	sed "s/\[\[APP_KEY\]\]/$GATEWAY_APP_KEY/g" | \
  	sed "s/\[\[GATEWAY_ID\]\]/$GATEWAY_ID/g" | \
    sed "s/\[\[DOCKER_ID\]\]/$DOCKER_ID/g" | \
    sed "s/\[\[BLOCKCHAIN\]\]/$blockchain/g" | \
    sed "s/\[\[NETWORK\]\]/$network/g" | \
    sed "s/\[\[ZONE\]\]/$zone/g" \
  	> $ENV_DIR/gateways/docker-compose-${DOCKER_ID}.yaml
  docker-compose -f $ENV_DIR/gateways/docker-compose-${DOCKER_ID}.yaml up -d --force-recreate
  #State6 waiting for gateway approval
  docker exec mbr_proxy_$network_number /test/scripts/test_main_flow.sh _check_provider_status gateway approved $GATEWAY_ID
  #State4: Stake gateway
  docker exec mbr_proxy_$network_number /test/scripts/test_main_flow.sh _stake_provider Gateway $GATEWAY_ID
done
