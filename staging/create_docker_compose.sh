#!/bin/bash
ROOT_DIR=$(dirname $(realpath $0))
source $ROOT_DIR/base.sh
bash -x $ROOT_DIR/create_git.sh
#Get PRIVATE_GIT_READ
#PRIVATE_GIT_READ=$(docker exec -it mbr_git_$network_number cat /massbit/massbitroute/app/src/sites/services/git/data/env/git.env  | grep GIT_PRIVATE_READ_URL  | cut -d "=" -f 2 | sed "s/'//g" | sed "s|http://||g")
PRIVATE_GIT_READ=$(docker exec mbr_git_$network_number cat /massbit/massbitroute/app/src/sites/services/git/data/env/git.env  | grep GIT_PRIVATE_READ_URL  | cut -d "=" -f 2 | sed "s/'//g")
echo $PRIVATE_GIT_READ
echo SCHEDULER_AUTHORIZATION=$SCHEDULER_AUTHORIZATION > $ENV_DIR/fisherman/.env_fisherman
mkdir -p $ENV_DIR/templates
docker_compose_files=""
files="network-docker-compose db-docker-compose core-docker-compose portal-docker-compose fisherman-docker-compose"
for file in $files
do
  cat $ROOT_DIR/../common/templates/${file}.yaml.template |  \
       sed "s|\[\[ENV_DIR\]\]|$ENV_DIR|g" | \
       sed "s|\[\[ROOT_DIR\]\]|$ROOT_DIR|g" | \
       sed "s|\[\[PROTOCOL\]\]|$PROTOCOL|g" | \
       sed "s/\[\[NETWORK_NUMBER\]\]/$network_number/g" | \
       #Ips
       sed "s/\[\[PROXY_IP\]\]/$PROXY_IP/g" | \
       sed "s/\[\[TEST_CLIENT_IP\]\]/$TEST_CLIENT_IP/g" | \
       sed "s/\[\[MASSBIT_CHAIN_IP\]\]/$MASSBIT_CHAIN_IP/g" | \
       sed "s/\[\[STAKING_IP\]\]/$STAKING_IP/g" | \
       sed "s/\[\[FISHERMAN_SCHEDULER_IP\]\]/$FISHERMAN_SCHEDULER_IP/g" | \
       sed "s/\[\[FISHERMAN_WORKER01_IP\]\]/$FISHERMAN_WORKER01_IP/g" | \
       sed "s/\[\[FISHERMAN_WORKER02_IP\]\]/$FISHERMAN_WORKER02_IP/g" | \
       sed "s/\[\[FISHER_ENVIRONMENT\]\]/$FISHER_ENVIRONMENT/g" | \
       sed "s/\[\[PORTAL_IP\]\]/$PORTAL_IP/g" | \
       sed "s/\[\[CHAIN_IP\]\]/$CHAIN_IP/g" | \
       sed "s/\[\[WEB_IP\]\]/$WEB_IP/g" | \
       sed "s/\[\[GWMAN_IP\]\]/$GWMAN_IP/g" | \
       sed "s/\[\[POSTGRES_IP\]\]/$POSTGRES_IP/g" | \
       sed "s/\[\[REDIS_IP\]\]/$REDIS_IP/g" | \
       sed "s/\[\[GIT_IP\]\]/$GIT_IP/g" | \
       sed "s/\[\[API_IP\]\]/$API_IP/g" | \
       sed "s/\[\[SESSION_IP\]\]/$SESSION_IP/g" | \
       sed "s/\[\[SCHEDULER_AUTHORIZATION\]\]/$SCHEDULER_AUTHORIZATION/g" | \
       sed "s|\[\[MASSBIT_ROUTE_SID\]\]|$MASSBIT_ROUTE_SID|g" | \
       sed "s|\[\[MASSBIT_ROUTE_PARTNER_ID\]\]|$MASSBIT_ROUTE_PARTNER_ID|g" \
      > $ENV_DIR/templates/${file}.yaml.template
  cat $ENV_DIR/templates/${file}.yaml.template | sed "s|\[\[PRIVATE_GIT_READ\]\]|$PRIVATE_GIT_READ|g" > $ENV_DIR/${file}.yaml
  docker_compose_files="$docker_compose_files -f $ENV_DIR/${file}.yaml"
done
echo "docker-compose -f network-docker-compose.yaml -f db-docker-compose.yaml --env-file /massbit/test_runtime/10/envs/.env up -d --force-recreate" > $ENV_DIR/start_core.sh
echo "sleep 30" >> $ENV_DIR/start_core.sh
echo "docker-compose -f network-docker-compose.yaml -f core-docker-compose.yaml -f portal-docker-compose.yaml -f fisherman-docker-compose.yaml --env-file /massbit/test_runtime/10/envs/.env up -d --force-recreate" >> $ENV_DIR/start_core.sh
chmod +x $ENV_DIR/start_core.sh
#add extra host file for fisherman scheduler
#stat & monitor
roles="stat monitor"
for role in $roles
do
  for chain in ${!blockchains[@]}
  do
     networks=(${blockchains[$chain]});
     for net in ${networks[@]}
     do
       #node stat
       START_IP=$(( $START_IP + 1 ))
       IP=172.24.$network_number.$START_IP
       server_name=node-${chain}-${net}.${role}.mbr.$domain
       #echo "      - ${server_name}:${IP}" >> $ENV_DIR/fisherman-docker-compose.yaml
       #gateway stat
       START_IP=$(( $START_IP + 1 ))
       IP=172.24.$network_number.$START_IP
       server_name=gateway-${chain}-${net}.${role}.mbr.$domain
       #echo "      - ${server_name}:${IP}" >> $ENV_DIR/fisherman-docker-compose.yaml
     done
  done
done
#docker-compose -f $ENV_DIR/docker-compose.yaml up -d --force-recreate
#docker-compose $docker_compose_files up -d --force-recreate
#sleep 30
#docker exec mbr_api bash -c '/massbit/massbitroute/app/src/sites/services/api/cmd_server start nginx'
#docker exec mbr_portal_api_$network_number bash -c 'cd /app; npm run dbm:init'
#docker exec mbr_db_$network_number bash -c 'bash /docker-entrypoint-initdb.d/3_init_user.sh'
#docker exec mbr_db_$network_number bash -c 'bash /docker-entrypoint-initdb.d/2_clean_node.sh'

bash -x $ROOT_DIR/create_stat_docker_compose.sh
