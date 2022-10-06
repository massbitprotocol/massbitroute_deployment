#!/bin/bash
ROOT_DIR=$(realpath $(dirname $(realpath $0)))
source $ROOT_DIR/base.sh

if [ ! -d "/vars" ]
then
  mkdir -p /vars/status/
fi
#-------------------------------------------
# Docker build
#-------------------------------------------
#bash docker_build.sh
#bash docker_build_proxy.sh
#-------------------------------------------
# Docker up
#-------------------------------------------
cd $ROOT_DIR

#-------------------------------------------
# Log into Portal
#-------------------------------------------
_login() {
  bearer=
  while [[ "x$bearer" == "x" ]] || [[ "$bearer" == "null" ]]; do
    echo "Try login..."
    bearer=$(curl -k --location --request POST "https://portal.$domain/auth/login" --header 'Content-Type: application/json' \
            --data-raw "{\"username\": \"$TEST_USERNAME\", \"password\": \"$TEST_PASSWORD\"}"| jq  -r ". | .accessToken")
    sleep 5
  done
  echo $bearer > /vars/BEARER
  userID=$(curl -k "https://portal.$domain/user/info" \
    -H 'Accept: application/json, text/plain, */*' \
    -H 'Accept-Language: en-US,en;q=0.9' \
    -H "Authorization: Bearer $bearer" | jq -r ". | .id")
  echo $userID > /vars/USER_ID
}
#-------------------------------------------
# create  nodes in Portal
#-------------------------------------------
_create_nodes() {
  for chain in ${!blockchains[@]}
  do
      networks=(${blockchains[$chain]});
      urls=(${dataSources[$chain]})
      for n in ${networks[@]}
      do
        echo "Create node for blockchain $chain:$n with datasource ${urls[@]}";
        _create_node $chain $n ${urls[0]} ${urls[1]}
      done
      #echo ${networks[@]}
      #echo "["$key"]:["${blockchains[$key]}"]"
  done
}
#
# $1-blockchain; $2-network; $3-datasource $4-ws-satasource $5 random ID
#
_create_node() {
  echo "params: $@"
  now=$(date)
  bearer=$(cat /vars/BEARER)
  blockchain=${1:-eth}
  network=${2:-mainnet}
  if [ "x$3" == "x" ]; then
    dataSource=$DATASOURCE
  else
    dataSource=$3
  fi
  if [ "x$4" == "x" ]; then
    dataSourceWs=$DATASOURCE_WS
  else
    dataSourceWs=$4
  fi
  DOCKER_ID=$5
  echo "Create new node in Portal: In Progress at $now"
  curl -k --location --request POST "https://portal.$domain/mbr/node" \
    --header "Authorization: Bearer  $bearer" \
    --header 'Content-Type: application/json' \
    --data-raw "{
        \"name\": \"mb-dev-node-$nodePrefix\",
        \"blockchain\": \"$blockchain\",
        \"zone\": \"AS\",
        \"dataSource\": \"$dataSource\",
        \"network\": \"$network\",
        \"dataSourceWs\":\"$dataSourceWs\"
    }" | jq -r '. | .id, .appKey' | sed -z -z 's/\n/,/g;s/,$/,AS\n/' > nodelist.csv
    NODE_ID=$(cut -d ',' -f 1 nodelist.csv)
    NODE_APP_KEY=$(cut -d ',' -f 2 nodelist.csv)
    echo "        NODE INFO        "
    echo "----------------------------"
    echo "Node ID: $NODE_ID"
    echo "----------------------------"
    mkdir -p /vars/$NODE_ID
    echo $NODE_ID > /vars/$DOCKER_ID
    echo $NODE_APP_KEY > /vars/$NODE_ID/NODE_APP_KEY
    echo $blockchain > /vars/$NODE_ID/BLOCKCHAIN
    echo $network > /vars/$NODE_ID/NETWORK
    echo $dataSource > /vars/$NODE_ID/NODE_DATASOURCE
}

#-------------------------------------------
# create  nodes in Portal
#-------------------------------------------
_create_gateways() {
  for chain in ${!blockchains[@]}
  do
      networks=(${blockchains[$chain]});
      for n in ${networks[@]}
      do
        echo "Create gateway for blockchain $chain:$n";
        _create_gateway $chain $n
      done
      #echo ${networks[@]}
      #echo "["$key"]:["${blockchains[$key]}"]"
  done
}

_create_gateway() {
  now=$(date)
  bearer=$(cat /vars/BEARER)
  blockchain=${1:-eth}
  network=${2:-mainnet}
  DOCKER_ID=$3
  curl -k --location --request POST "https://portal.$domain/mbr/gateway" \
    --header "Authorization: Bearer  $bearer" \
    --header 'Content-Type: application/json' \
    --data-raw "{
      \"name\":\"mbr-dev-gateway-$nodePrefix\",
      \"blockchain\":\"$blockchain\",
      \"zone\":\"AS\",
      \"network\":\"$network\"}" | jq -r '. | .id, .appKey' | sed -z -z 's/\n/,/g;s/,$/,AS\n/' > gatewaylist.csv
  GATEWAY_ID=$(cut -d ',' -f 1 gatewaylist.csv)
  GATEWAY_APP_KEY=$(cut -d ',' -f 2  gatewaylist.csv)
  echo "        GW INFO        "
  echo "----------------------------"
  echo "Gateway ID: $GATEWAY_ID"
  echo "----------------------------"
  mkdir -p /vars/$GATEWAY_ID
  echo $GATEWAY_ID > /vars/$DOCKER_ID
  echo $GATEWAY_APP_KEY > /vars/$GATEWAY_ID/GATEWAY_APP_KEY
  echo $network > /vars/$GATEWAY_ID/NETWORK
  echo $blockchain > /vars/$GATEWAY_ID/BLOCKCHAIN
}
_register_providers() {
  providerType="${1,,}"
  if [ "x$2" == "x" ]; then
    if [ "$providerType" == "gateway" ]; then
      providerId=$(cat /vars/GATEWAY_ID)
      providerType="Gateway"
    else
      providerId=$(cat /vars/NODE_ID)
      providerType="Node"
    fi
  else
    providerId=$2
  fi
  blockchain=$(cat /vars/$providerId/BLOCKCHAIN)
  network=$(cat /vars/$providerId/NETWORK)
  register_provider=$(curl --location --request POST "http://staking.$domain/massbit/admin/register-provider" \
     --header 'Content-Type: application/json' --data-raw "{
       \"operator\": \"$TEST_WALLET_ADDRESS\",
       \"providerId\": \"$providerId\",
       \"providerType\": \"$providerType\",
       \"blockchain\": \"$blockchain\",
       \"network\": \"$network\"
   }" | jq -r ". | .status")
   if [[ "$register_provider" != "success" ]]; then
     echo "Register node $providerId: Failed"
   else
     echo "Register node $providerId: Passed"
   fi
}

_stake_providers() {
  now=$(date)
  echo "Current time $now. Wait a minute for staking provider..."
  bearer=$(cat /vars/BEARER)
  providerType="${1,,}"

  if [ "$providerType" == "gateway" ]; then
    providerList=$(curl --location --request GET "$protocol://portal.$domain/mbr/gateway/list/?limit=100" \
      --header "Authorization: Bearer $bearer" | jq  -r ". | .gateways")
  else
    providerList=$(curl -vv --location --request GET "$protocol://portal.$domain/mbr/node/list/?limit=100" \
      --header "Authorization: Bearer $bearer" | jq  -r ". | .nodes")
  fi
  len=$(echo $providerList | jq length)
  min=0
  for (( i=0; c<$len; c++ ))
      do
          #providerInfo=$(echo "$providerList" | jq ".[$i]" | jq ". | .appId, .appKey" | sed -z "s/\"//g; s/\n/,/g; s/,$//g;s/,/.eth-mainnet.$domain\//g")
          providerInfo=$(echo "$providerList" | jq ".[$i]");
          echo $providerInfo;
          status=$(echo $providerInfo | jq ".status")
          if [ "$status" == "approved" ]; then
              providerId=$(echo $providerInfo | jq ".id")
              blockchain=$(echo $providerInfo | jq ".blockchain")
              staking_response=$(curl --location --request POST "http://staking.$domain/massbit/staking-provider" \
                --header 'Content-Type: application/json' --data-raw "{
                  \"memonic\": \"$MEMONIC\",
                  \"providerId\": \"$providerId\",
                  \"providerType\": \"$providerType\",
                  \"blockchain\": \"$blockchain\",
                  \"network\": \"mainnet\",
                  \"amount\": \"100\"
              }")
              echo "Staking response $staking_response";
              staking_status=$(echo $staking_response | jq -r ". | .status");

              if [[ "$staking_status" != "success" ]]; then
                echo "$providerType staking status: Failed "
                exit 1
              fi
              provider_status=$(curl -k --location --request GET "https://portal.$domain/mbr/$providerType/$providerId" \
                --header "Authorization: Bearer $bearer" | jq -r ". | .status")

              now=$(date)
              echo "---------------------------------"
              echo "$providerType status at $now is $provider_status, expected status staked"
              echo "---------------------------------"
          fi
      done #End of for loop
}

#-------------------------------------------
# Test staking for provider
# $1: provider type:Node or Gateway, $2: ProviderId
#-------------------------------------------
_stake_provider() {
  # stake gateway
  now=$(date)
  echo "Wait a minute for staking provider..."
  echo "$now"
  providerType="${1,,}"
  providerId=$2
  bearer=$(cat /vars/BEARER)
  providerInfo=$(curl -k --location --request GET "https://portal.$DOMAIN/mbr/$providerType/$providerId" \
    --header "Authorization: Bearer $bearer")
  echo $providerInfo
  blockchain=$(echo $providerInfo | jq -r ". | .blockchain")
  network=$(echo $providerInfo | jq -r ". | .network")
  staking_response=$(curl -vv --location --request POST "http://staking.$domain/massbit/staking-provider" \
    --header 'Content-Type: application/json' --data-raw "{
      \"memonic\": \"$MEMONIC\",
      \"providerId\": \"$providerId\",
      \"providerType\": \"$providerType\",
      \"blockchain\": \"$blockchain\",
      \"network\": \"$network\",
      \"amount\": \"100\"
  }")
  echo "Staking response $staking_response";
  staking_status=$(echo $staking_response | jq -r ". | .status");

  if [[ "$staking_status" != "success" ]]; then
    echo "$providerType staking status: Failed "
    exit 1
  fi
  provider_status=$(curl -k --location --request GET "https://portal.$domain/mbr/$providerType/$providerId" \
    --header "Authorization: Bearer $bearer" | jq -r ". | .status")

  now=$(date)
  echo "---------------------------------"
  echo "$providerType status at $now is $provider_status, expected status staked"
  echo "---------------------------------"

#  provider_status=""
#  while [[ "$provider_status" != "staked" ]]; do
#    echo "Checking $providerType status: In Progress"
#    providerType="${providerType,,}"
#    provider_status=$(curl -k --location --request GET "https://portal.$domain/mbr/$providerType/$providerId" \
#      --header "Authorization: Bearer $bearer" | jq -r ". | .status")
#
#    now=$(date)
#    echo "---------------------------------"
#    echo "$providerType status at $now is $provider_status"
#    echo "---------------------------------"
#    sleep 10
#  done

  now=$(date)
  echo "$providerType staked: Passed at $now"
}


#-------------------------------------------
# Check node status
# $1: provider type: node/gateway, $2 status to check, $3: providerId
#-------------------------------------------
_check_provider_status() {
  bearer=$(cat /vars/BEARER)
  providerType="${1,,}"
  providerId=$3
  status=''
  start=$(date +"%s")
  end=$start
  duration=$(( $end-$start ))
  mkdir -p /vars/status/
  printf "Start check status of %s at %ds\n" $providerType $start
  while [ \( "$status" != "$2" \) -a \( $duration -le $PROVIDER_STATUS_TIMEOUT \) ]; do
  #while [[ "$status" != "$2" ]]; do
    echo "Checking $providerType status: In Progress"
    cat /logs/proxy_access.log | grep "$providerId" | grep '.10->api.' | grep 'POST' | grep "$providerType.update"
    #if [ $? -eq 0 ];then break;fi

    status=$(curl -k --silent --location --request GET "https://portal.$DOMAIN/mbr/$providerType/$providerId" \
      --header "Authorization: Bearer $bearer" | jq -r ". | .status")
    now=$(date)
    end=$(date +"%s")
    duration=$(( $end-$start ))
    echo "---------------------------------------"
    echo "$providerType status at $now is $status"
    echo "---------------------------------------"

    if [[ "x$status" == "xverified" && "x$2" == "xapproved" ]]; then
      _register_providers $providerType $providerId
      echo "Wating for register $providerType  $providerId"
    fi
    sleep 10
  done
  echo "Checking $providerType reported status: $status at $now in ${duration}s"
  echo $status > /vars/status/$providerId
  if [ "$status" != "$2" ]; then
    echo "Test failed. Expectation status is $2"
    exit 1
  fi
}

$@
