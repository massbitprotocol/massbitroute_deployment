#!/bin/bash
ROOT_DIR=$(dirname $(realpath $0))
export TEST_ENV=${1:-local}
export network_number=${2:-10}
source $ROOT_DIR/base.sh

mkdir -p $ENV_DIR/vars
mkdir -p $ENV_DIR/nodes
mkdir -p $ENV_DIR/gateways
mkdir -p $ENV_DIR/envs
bash ../common/check_latest_tag.sh _read_latest_git_tags
#Create if not exists network
echo "--------------------------------------------"
echo "Creating network 172.24.$network_number.0/24"
echo "--------------------------------------------"
CHECKNETWORK=$(docker network inspect $network_name >/dev/null 2>&1 && echo 1 || echo 0)
if [ "$CHECKNETWORK" == "0" ]; then
  docker network create -d bridge --gateway "172.24.$network_number.1" --subnet "172.24.$network_number.0/24" $network_name
fi
cp -r $ROOT_DIR/../common/migrations $ENV_DIR
cp -r $ROOT_DIR/../common/scheduler $ENV_DIR
cp -r $ROOT_DIR/../common/fisherman $ENV_DIR
cp -r $ROOT_DIR/envs $ENV_DIR
cat $ROOT_DIR/envs/.env \
  | sed "s/\[\[NETWORK_NUMBER\]\]/$network_number/g" \
  > $ENV_DIR/envs/.env

bash -x $ROOT_DIR/prepare_proxy.sh
bash -x create_docker_compose.sh

#rsync -avz migrations $ENV_DIR/
#rsync -avz scheduler $ENV_DIR/
#rsync -avz fisherman $ENV_DIR/

#Create node template
cat $ROOT_DIR/../common/templates/node-docker-compose.yaml.template | \
    sed "s|\[\[PROTOCOL\]\]|$PROTOCOL|g" | \
    sed "s|\[\[GIT_PRIVATE_BRANCH\]\]|$GIT_PRIVATE_BRANCH|g" | \
    sed "s/\[\[NETWORK_NUMBER\]\]/$network_number/g" | \
		sed "s/\[\[NODE_TAG\]\]/$NODE_TAG/g" | \
    sed "s/\[\[CHAIN_IP\]\]/$CHAIN_IP/g" | \
    sed "s/\[\[PROXY_IP\]\]/$PROXY_IP/g" \
    > $ENV_DIR/templates/node-docker-compose.yaml.template


#Create gateway template
cat $ROOT_DIR/../common/templates/gateway-docker-compose.yaml.template | \
    sed "s|\[\[PROTOCOL\]\]|$PROTOCOL|g" | \
    sed "s|\[\[GIT_PRIVATE_BRANCH\]\]|$GIT_PRIVATE_BRANCH|g" | \
    sed "s/\[\[NETWORK_NUMBER\]\]/$network_number/g" | \
		sed "s/\[\[GATEWAY_TAG\]\]/$GATEWAY_TAG/g" | \
    sed "s/\[\[CHAIN_IP\]\]/$CHAIN_IP/g" | \
    sed "s/\[\[PROXY_IP\]\]/$PROXY_IP/g" \
	 	> $ENV_DIR/templates/gateway-docker-compose.yaml.template


cp base.sh $ENV_DIR/
cp read_tags.sh $ENV_DIR/
echo "source $ENV_DIR/read_tags.sh" >> $ENV_DIR/base.sh
echo "source $ENV_DIR/envs/.env" >> $ENV_DIR/base.sh

cat $ROOT_DIR/start.sh \
  | sed "s/\[\[NETWORK_NUMBER\]\]/$network_number/g" \
  | sed "s/\[\[COMMAND_CORE_DOCKER_COMPOSE\]\]/$COMMAND_CORE_DOCKER_COMPOSE/g" \
  | sed "s/\[\[COMMAND_STAT_DOCKER_COMPOSE\]\]/$COMMAND_STAT_DOCKER_COMPOSE/g" \
  > $ENV_DIR/start.sh
chmod +x $ENV_DIR/start.sh

mkdir -p $ENV_DIR/scenarios
cp $ROOT_DIR/../common/scenarios/*.* $ENV_DIR/scenarios
cp -r $ROOT_DIR/../common/scripts $ENV_DIR
#bash -x $ENV_DIR/start.sh
