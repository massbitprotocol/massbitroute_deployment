#!/bin/bash
ROOT_DIR=$(dirname $(realpath $0))
source $ROOT_DIR/base.sh
export git=$(cat $ENV_DIR/vars/git)
export GIT_TAG=${GIT_TAG:-$git}
echo "Git tag: $GIT_TAG"
cat $ROOT_DIR/../common/templates/git-docker-compose.yaml.template |  \
     #sed "s/\[\[RUN_ID\]\]/$network_number/g" | \
     sed "s|\[\[PROTOCOL\]\]|$PROTOCOL|g" | \
     sed "s|\[\[STAT_PROMETHEUS_SCHEME\]\]|$PROTOCOL|g" | \
     sed "s/\[\[NETWORK_NUMBER\]\]/$network_number/g" | \
     sed "s/\[\[GIT_TAG\]\]/$GIT_TAG/g" | \
     sed "s/\[\[PROXY_IP\]\]/$PROXY_IP/g" | \
     sed "s/\[\[GIT_IP\]\]/$GIT_IP/g" | \
     sed "s/\[\[CHAIN_IP\]\]/$CHAIN_IP/g"  \
    > $ENV_DIR/git-docker-compose.yaml
#cp git-docker-compose.yaml $ENV/git-docker-compose.yaml
#Init docker
docker-compose -f $ENV_DIR/git-docker-compose.yaml up -d --force-recreate
sleep 10
docker exec mbr_git_$network_number rm -rf /massbit/massbitroute/app/src/sites/services/git/data/*
docker exec mbr_git_$network_number rm -rf /massbit/massbitroute/app/src/sites/services/git/vars/*
docker exec mbr_git_$network_number /massbit/massbitroute/app/src/sites/services/git/scripts/run _repo_init
echo "export SID=$MASSBIT_ROUTE_SID" > $ENV_DIR/git/data/env/api.env
echo "export PARTNER_ID=$MASSBIT_ROUTE_PARTNER_ID" >> $ENV_DIR/git/data/env/api.env
docker exec mbr_git_$network_number cat /massbit/massbitroute/app/src/sites/services/git/data/env/api.sh
docker exec mbr_git_$network_number /massbit/massbitroute/app/src/sites/services/git/scripts/run _repo_init
docker exec mbr_git_$network_number cat /massbit/massbitroute/app/src/sites/services/git/data/env/env.sh
sleep 10
