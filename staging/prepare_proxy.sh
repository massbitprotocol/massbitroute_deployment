#!/bin/bash
ROOT_DIR=$(dirname $(realpath $0))
PROXY_DIR=$ENV_DIR/proxy
mkdir -p $PROXY_DIR
source $ROOT_DIR/base.sh
cat $ROOT_DIR/../common/templates/hosts.template | \
  sed "s/\[\[NETWORK_NUMBER\]\]/$network_number/g" | \
  sed "s/\[\[PROXY_IP\]\]/$PROXY_IP/g" | \
  sed "s/\[\[TEST_CLIENT_IP\]\]/$TEST_CLIENT_IP/g" | \
  sed "s/\[\[MASSBIT_CHAIN_IP\]\]/$MASSBIT_CHAIN_IP/g" | \
  sed "s/\[\[STAKING_IP\]\]/$STAKING_IP/g" | \
  sed "s/\[\[FISHERMAN_SCHEDULER_IP\]\]/$FISHERMAN_SCHEDULER_IP/g" | \
  sed "s/\[\[FISHERMAN_WORKER01_IP\]\]/$FISHERMAN_WORKER01_IP/g" | \
  sed "s/\[\[FISHERMAN_WORKER02_IP\]\]/$FISHERMAN_WORKER02_IP/g" | \
  sed "s/\[\[PORTAL_IP\]\]/$PORTAL_IP/g" | \
  sed "s/\[\[CHAIN_IP\]\]/$CHAIN_IP/g" | \
  sed "s/\[\[WEB_IP\]\]/$WEB_IP/g" | \
  sed "s/\[\[GWMAN_IP\]\]/$GWMAN_IP/g" | \
  sed "s/\[\[GIT_IP\]\]/$GIT_IP/g" | \
  sed "s/\[\[API_IP\]\]/$API_IP/g" | \
  sed "s/\[\[SESSION_IP\]\]/$SESSION_IP/g" \
  > $PROXY_DIR/hosts

declare -A hosts
#git clone http://massbit:DaTR__SGr89IjgvcwBtJyg0v_DFySDwI@git.massbitroute.net/massbitroute/ssl.git -b shamu ssl
_IFS=$IFS
while IFS=":" read -r server_name ip
do
  hosts[$server_name]=$ip
done < <(cat $PROXY_DIR/hosts)
IFS=$_IFS
cat $ROOT_DIR/../common/docker-proxy/common.conf | \
  sed "s/\[\[NETWORK_NUMBER\]\]/$network_number/g" | \
  sed "s/\[\[PORXY_IP\]\]/$PORXY_IP/g" | \
  sed "s/\[\[TEST_CLIENT_IP\]\]/$TEST_CLIENT_IP/g" | \
  sed "s/\[\[MASSBIT_CHAIN_IP\]\]/$MASSBIT_CHAIN_IP/g" | \
  sed "s/\[\[STAKING_IP\]\]/$STAKING_IP/g" | \
  sed "s/\[\[FISHERMAN_SCHEDULER_IP\]\]/$FISHERMAN_SCHEDULER_IP/g" | \
  sed "s/\[\[FISHERMAN_WORKER01_IP\]\]/$FISHERMAN_WORKER01_IP/g" | \
  sed "s/\[\[FISHERMAN_WORKER02_IP\]\]/$FISHERMAN_WORKER02_IP/g" | \
  sed "s/\[\[SCHEDULER_AUTHORIZATION\]\]/$SCHEDULER_AUTHORIZATION/g" | \
  sed "s/\[\[PORTAL_IP\]\]/$PORTAL_IP/g" | \
  sed "s/\[\[CHAIN_IP\]\]/$CHAIN_IP/g" | \
  sed "s/\[\[WEB_IP\]\]/$WEB_IP/g" | \
  sed "s/\[\[GWMAN_IP\]\]/$GWMAN_IP/g" | \
  sed "s/\[\[GIT_IP\]\]/$GIT_IP/g" | \
  sed "s/\[\[API_IP\]\]/$API_IP/g" | \
  sed "s/\[\[SESSION_IP\]\]/$SESSION_IP/g" \
  > $PROXY_DIR/nginx.conf
domain=massbitroute.net
servers=("session.mbr" "api" "portal" "admin-api" "dapi" "staking" "hostmaster" "ns1" "ns2")
for server in ${servers[@]}; do
  server_name=$server.$domain
  echo "Generate server block for $server_name with ip ${hosts[$server_name]}"
  #openssl req -x509 -nodes -days 7300 -newkey rsa:2048 -subj "/C=PE/ST=Lima/L=Lima/O=Acme Inc. /OU=IT Department/CN=$server_name" -keyout $ROOT/docker-proxy/ssl/selfsigned/${server_name}.key -out $ROOT/docker-proxy/ssl/selfsigned/${server_name}.cert
  cat $ROOT_DIR/../common/docker-proxy/server.template | sed "s/\[\[SERVER_NAME\]\]/$server_name/g" | sed "s/\[\[DOMAIN\]\]/$domain/g" |  sed "s/\[\[IP\]\]/${hosts[$server_name]}/g" >> $PROXY_DIR/nginx.conf
done

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
       echo "Generate server block for $server_name with ip $IP"
       #openssl req -x509 -nodes -days 7300 -newkey rsa:2048 -subj "/C=PE/ST=Lima/L=Lima/O=Acme Inc. /OU=IT Department/CN=$server_name" -keyout $ROOT/docker-proxy/ssl/selfsigned/${server_name}.key -out $ROOT/docker-proxy/ssl/selfsigned/${server_name}.cert
       cat $ROOT_DIR/../common/docker-proxy/server.template | sed "s/\[\[SERVER_NAME\]\]/$server_name/g" | sed "s/\[\[DOMAIN\]\]/$domain/g" |  sed "s/\[\[IP\]\]/$IP/g" >> $PROXY_DIR/nginx.conf
       #gateway stat
       START_IP=$(( $START_IP + 1 ))
       IP=172.24.$network_number.$START_IP
       server_name=gateway-${chain}-${net}.${role}.mbr.$domain
       echo "Generate server block for $server_name with ip $IP"
       #openssl req -x509 -nodes -days 7300 -newkey rsa:2048 -subj "/C=PE/ST=Lima/L=Lima/O=Acme Inc. /OU=IT Department/CN=$server_name" -keyout $ROOT/docker-proxy/ssl/selfsigned/${server_name}.key -out $ROOT/docker-proxy/ssl/selfsigned/${server_name}.cert
       cat $ROOT_DIR/../common/docker-proxy/server.template | sed "s/\[\[SERVER_NAME\]\]/$server_name/g" | sed "s/\[\[DOMAIN\]\]/$domain/g" |  sed "s/\[\[IP\]\]/$IP/g" >> $PROXY_DIR/nginx.conf

     done
  done
done
cp -r $ROOT_DIR/../common/test $ENV_DIR/proxy
bash $ROOT_DIR/../common/docker_build.sh
#echo "nameserver 172.24.${network_number}.$GWMAN_IP" > $PROXY_DIR/resolv.conf
