#!/bin/bash
ROOT_DIR=$(realpath $(dirname $(realpath $0)))
source $ROOT_DIR/../base.sh
SCENARIO_ID="$(echo $RANDOM | md5sum | head -c 5)"
echo '-------------------------------------------------------';
echo "Run scenario ${BASH_SOURCE[0]} with ID $SCENARIO_ID----";
echo '-------------------------------------------------------';
blockchain=dot
network=mainnet
zone=AS
DOCKER_ID=$(echo $RANDOM | md5sum | head -c 5)
dataSource="https://34.87.134.109"
dataSourceWs="wss://34.87.134.109/websocket"
#State2: Create node
docker exec mbr_proxy_$network_number /test/scripts/test_main_flow.sh _create_node $blockchain $network $dataSource $dataSourceWs $DOCKER_ID
NODE_ID=$(cat $ENV_DIR/proxy/vars/${DOCKER_ID}/NODE_ID)
NODE_APP_KEY=$(cat $ENV_DIR/proxy/vars/${DOCKER_ID}/NODE_APP_KEY)
NODE_DATASOURCE=$(cat $ENV_DIR/proxy/vars/${DOCKER_ID}/NODE_DATASOURCE)
USER_ID=$(cat $ENV_DIR/proxy/vars/USER_ID)
if [ "$NODE_ID" == "null" ]; then
  echo 'Test failed'
  exit 1
fi
cat $ENV_DIR/node-docker-compose.yaml.template | \
    sed "s/\[\[USER_ID\]\]/$USER_ID/g" | \
    sed "s/\[\[APP_KEY\]\]/$NODE_APP_KEY/g" | \
    sed "s/\[\[NODE_ID\]\]/$NODE_ID/g" | \
    sed "s|\[\[DATA_URL\]\]|$NODE_DATASOURCE|g" | \
    sed "s/\[\[DOCKER_ID\]\]/$DOCKER_ID/g" | \
    sed "s/\[\[BLOCKCHAIN\]\]/$blockchain/g" | \
    sed "s/\[\[NETWORK\]\]/$network/g" | \
    sed "s/\[\[ZONE\]\]/$zone/g" \
    > $ENV_DIR/node-docker-compose-${DOCKER_ID}.yaml
#State3: Create docker node
docker-compose -f $ENV_DIR/node-docker-compose-${DOCKER_ID}.yaml up -d --force-recreate
#State4 waiting for node approval
docker exec mbr_proxy_$network_number /test/scripts/test_main_flow.sh _check_provider_status node approved $NODE_ID
#State4: Stake node
docker exec mbr_proxy_$network_number /test/scripts/test_main_flow.sh _stake_provider node $NODE_ID
