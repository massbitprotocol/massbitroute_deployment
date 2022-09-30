#!/bin/bash
ROOT_DIR=$(realpath $(dirname $(realpath $0)))
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source $ROOT_DIR/base.sh
dapi_counter=10
# ==============================
# Limit test run
# ==============================
export NUMBER_OF_TESTS=1
# ==============================
# Directory store report
# ==============================
export REPORT_DIR=/reports
# ==============================
# Your account's private key
# ==============================
export ETHEREUM_PRIVATE_KEY="ETHEREUM_PRIVATE_KEY"
# ==============================
# EOA address for receiving ETH
# ==============================
export ETHEREUM_EOA_ADDRESS="ETHEREUM_EOA_ADDRESS (eg. 0x80143CBe15fbC4ff9CaDaD378418C20659A2E919)"
# ==============================
# Infura provider url
# ==============================
#export ANOTHER_ETHEREUM_PROVIDER="https://rinkeby.infura.io/v3/2b9f6488f50f4e3b95d8aa375ce146d1"
export ANOTHER_ETHEREUM_PROVIDER="https://main-light.eth.linkpool.io"
# ==============================
# Polkadot provider url
# ==============================
export ANOTHER_POLKADOT_PROVIDER="https://rpc.polkadot.io"
#-------------------------------------------
# Create project
#-------------------------------------------
# ==============================
# Ethereum network name (eg. rinkeby, mainnet)
# ==============================
export ETHEREUM_NETWORK="rinkeby"
# ==============================
# Ethereum mainnet datasource
# ==============================
# export MASSBIT_ROUTE_ETHEREUM="http://34.81.232.186:8545"
# ==============================
# Ethereum rinkeby datasource
# ==============================
export MASSBIT_ROUTE_ETHEREUM="http://35.240.241.166:8545"
# ==============================
# Polkadot datasource
# ==============================
export MASSBIT_ROUTE_POLKADOT="http://172.104.56.238:9933"

mkdir -p $REPORT_DIR
#
#
#
_init_params() {
  #echo "All params $@";
  ARGS=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      -s|--scenario)
        export scenario="$2"
        shift # past argument
        shift # past value
        ;;
      -b|--blockchain)
        export blockchain="$2"
        shift # past argument
        shift # past value
        ;;
      -n|--network)
        export network="$2"
        shift # past argument
        shift # past value
        ;;
      *)
        ARGS+=("$1") # save positional arg
        shift # past argument
        ;;
    esac
  done
}
#
# $1 - blockchain; $2 - network
#
_create_project() {
  now=$(date)
  bearer=$(cat /vars/BEARER)
  blockchain=$1
  network=$2
  projectName=project_$projectPrefix
  projectId=$(curl -k --location --request POST "https://portal.$domain/mbr/d-apis/project" \
    --header "Authorization: Bearer  $bearer" \
    --header 'Content-Type: application/json' \
    --data-raw "{
      \"name\":\"$projectName\",
      \"blockchain\":\"$blockchain\",
      \"network\":\"$network\"}" | jq -r '. | .id');

  echo "-----------------------------------"
  echo "Staking project with ID: $projectId"
  echo "-----------------------------------"
  echo $projectId > /vars/PROJECT_ID
  echo $projectName > /vars/PROJECT_NAME
  staking_response=$(curl --location --request POST "http://staking.$domain/massbit/staking-project" \
    --header 'Content-Type: application/json' --data-raw "{
      \"memonic\": \"$MEMONIC\",
      \"projectId\": \"$projectId\",
      \"blockchain\": \"$blockchain\",
      \"network\": \"$network\",
      \"amount\": \"${STAKING_AMOUNT_PROJECT}\"
  }")
  echo "Staking response $staking_response";
  staking_status=$(echo $staking_response | jq -r ". | .status");

  if [[ "$staking_status" != "success" ]]; then
    echo "Project staking status: Failed "
    exit 1
  fi
}

_stake_project() {
  # stake gateway
  now=$(date)
  blockchain=$1
  network=$2
  echo "Wait a minute for staking project. Current time $now ..."
  projectId=$(cat /vars/PROJECT_ID)

  staking_response=$(curl --location --request POST "http://staking.$domain/massbit/staking-project" \
    --header 'Content-Type: application/json' --data-raw "{
      \"memonic\": \"$MEMONIC\",
      \"projectId\": \"$projectId\",
      \"blockchain\": \"$blockchain\",
      \"network\": \"$network\",
      \"amount\": \"$STAKING_AMOUNT_PROJECT\"
  }")
  echo "Staking response $staking_response";
  staking_status=$(echo $staking_response | jq -r ". | .status");

  if [[ "$staking_status" != "success" ]]; then
    echo "Project staking status: Failed "
    exit 1
  fi

  now=$(date)
  echo "Project staked: Passed at $now"
}
#
# $1 - blockchain
# $2 - network
#
_create_dapi() {
  now=$(date)
  blockchain=$1
  network=$2
  echo "Create dapi at $now ..."
  bearer=$(cat /vars/BEARER)
  projectId=$(cat /vars/PROJECT_ID)
  projectName=$(cat /vars/PROJECT_NAME)
  random=$(echo $RANDOM | md5sum | head -c 3)
  create_dapi_response=$(curl --location --request POST "$protocol://portal.$domain/mbr/d-apis" \
    --header "Authorization: Bearer $bearer" \
    --header 'Content-Type: application/json' \
    --data-raw "{
      \"name\": \"$projectName-$random\",
      \"projectId\": \"$projectId\"
    }");
  echo $create_dapi_response;
  # status=$(echo $create_dapi_response | jq .status)
  # if [[ $status -ne 1 ]]; then
  #   echo "Can not create dapi. Test failed"
  #   exit 1
  # fi
  create_dapi_status=$(echo $create_dapi_response | jq .status)
  dApiId=$(echo $create_dapi_response | jq -r '. | .entrypoints[0].apiId')
  dApiAppKey=$(echo $create_dapi_response | jq -r '. | .appKey')
  dApiURL="$protocol://$dApiId.${blockchain}-$network.$domain/$dApiAppKey";
  echo "$dApiId.${blockchain}-$network.$domain" > "/vars/${blockchain}_${network}_DAPI_DOMAIN"
  echo $dApiAppKey > "/vars/${blockchain}_${network}_DAPI_APPKEY"
  echo $dApiURL > "/vars/${blockchain}_${network}_DAPI_URL"

  echo "---------dAPIUrl-----------------"
  echo "$dApiURL"
  echo "---------------------------------"
}

_prepare_dapis() {
    #-------------------------------------------
    # Create dAPI
    #-------------------------------------------
    now=$(date)
    echo "Prepare dapis at $now ..."
    bearer=$(cat /vars/BEARER)
    projectId=$(cat /vars/PROJECT_ID)
    projectName=$(cat /vars/PROJECT_NAME)
    dApis=$(curl -s --location --request GET "https://portal.$domain/mbr/d-apis/list/$projectId?limit=100" \
      --header "Authorization: Bearer $bearer" | jq  -r ". | .dApis")
    len=$(echo $dApis | jq length)
    end=$(( $dapi_counter - 1 ))
    if [ $len -lt $dapi_counter ]; then
      for i in $( seq $len $end );
      do
        random=$(echo $RANDOM | md5sum | head -c 3)
        create_dapi_response=$(curl -s --location --request POST "https://portal.$domain/mbr/d-apis" \
          --header "Authorization: Bearer $bearer" \
          --header 'Content-Type: application/json' \
          --data-raw "{
            \"name\": \"$projectName-$random\",
            \"projectId\": \"$projectId\"
          }")
        create_dapi_status=$(echo $create_dapi_response | jq .status)
        apiId=$(echo $create_dapi_response | jq -r '. | .entrypoints[0].apiId')
        appKey=$(echo $create_dapi_response | jq -r '. | .appKey')
        dapiURL="$protocol:\/\/$apiId.${blockchain}-$network.$domain\/$appKey"
        if [[ "$create_dapi_status" != "1" ]]; then
          echo "Create new dAPI: Failed"
          exit 1
        else
          echo "Create new dAPI: Passed"
        fi

      done
    fi
}

#
# $1 - blockchain, $2 - network
#
_execute_apis_testing() {
  export blockchain=$1
  export network=$2
  export PUBLIC_API=$3
  dApiDomain=$(cat "/vars/${blockchain}_${network}_DAPI_DOMAIN")
  dApiAppKey=$(cat "/vars/${blockchain}_${network}_DAPI_APPKEY")
  #dApiUrl=$(cat "/vars/${blockchain}_${network}_DAPI_URL")
  #dApiDomain=$(echo $dApiUrl | cut -d'/' -f3)
  gatewayIP=$(nslookup $dApiDomain 172.24.${NETWORK_NUMBER}.2 | awk -F':' '/Address: [0-9]/{sub(/^ /,"",$2);print $2}')
  export DAPI_DOMAIN=$dApiDomain
  dApiUrl="$protocol://$gatewayIP/$dApiAppKey"
  sed /$DAPI_DOMAIN/d -i /etc/hosts
  echo "$gatewayIP $DAPI_DOMAIN" >> /etc/hosts
  if [ "x$gatewayIP" == "x" ]; then
    echo "Can not resolve ip of $dApiDomain"
    exit 1
  fi
  if [ "$blockchain" == "eth" ]; then
    export MASSBIT_ROUTE_ETHEREUM="$dApiUrl"
    export ANOTHER_ETHEREUM_PROVIDER=${ANOTHER_ETHEREUM_PROVIDER:-$PUBLIC_API}
    echo "Test apis with endpoint: $MASSBIT_ROUTE_ETHEREUM";
    bash -x $SCRIPT_DIR/blockchain-api/ethereum/ethereum-test.sh
    bash -x $SCRIPT_DIR/blockchain-api/ethereum/ethereum-latency-test.sh
    #cd $SCRIPT_DIR/ethereum/flow-test && npm install && node index.js $NUMBER_OF_TESTS $MASSBIT_ROUTE_ETHEREUM $ANOTHER_ETHEREUM_PROVIDER $ETHEREUM_NETWORK $REPORT_DIR $ETHEREUM_PRIVATE_KEY $ETHEREUM_EOA_ADDRESS
  elif [ "$blockchain" == "dot" ]; then
    export MASSBIT_ROUTE_POLKADOT="$dApiUrl"
    export ANOTHER_POLKADOT_PROVIDER=${ANOTHER_POLKADOT_PROVIDER:-$PUBLIC_API}
    echo "Test apis with endpoint: $MASSBIT_ROUTE_POLKADOT";
    bash -x $SCRIPT_DIR/blockchain-api/polkadot/polkadot-test.sh
    bash -x $SCRIPT_DIR/blockchain-api/polkadot/polkadot-latency-test.sh
  fi
}

#
# $1 - blockchain, $2 - network
#
_call_apis() {
  export blockchain=$1
  export network=$2
  export LOOP=${3:-1}
  dApiDomain=$(cat "/vars/${blockchain}_${network}_DAPI_DOMAIN")
  dApiAppKey=$(cat "/vars/${blockchain}_${network}_DAPI_APPKEY")
  #dApiUrl=$(cat "/vars/${blockchain}_${network}_DAPI_URL")
  #dApiDomain=$(echo $dApiUrl | cut -d'/' -f3)
  gatewayIP=$(nslookup $dApiDomain 172.24.${NETWORK_NUMBER}.2 | awk -F':' '/Address: [0-9]/{sub(/^ /,"",$2);print $2}')
  export DAPI_DOMAIN=$dApiDomain
  dApiUrl="$protocol://$gatewayIP/$dApiAppKey"
  export MASSBIT_ROUTE_API="$dApiUrl"
  sed /$DAPI_DOMAIN/d -i /etc/hosts
  echo "$gatewayIP $DAPI_DOMAIN" >> /etc/hosts
  if [ "x$gatewayIP" == "x" ]; then
    echo "Can not resolve ip of $dApiDomain"
    exit 1
  fi
  if [ "$blockchain" == "eth" ]; then
    echo "Test apis with endpoint: $MASSBIT_ROUTE_API";
    bash -x $SCRIPT_DIR/blockchain-api/ethereum/ethereum-api-call.sh
    #cd $SCRIPT_DIR/ethereum/flow-test && npm install && node index.js $NUMBER_OF_TESTS $MASSBIT_ROUTE_ETHEREUM $ANOTHER_ETHEREUM_PROVIDER $ETHEREUM_NETWORK $REPORT_DIR $ETHEREUM_PRIVATE_KEY $ETHEREUM_EOA_ADDRESS
  elif [ "$blockchain" == "dot" ]; then
    echo "Test apis with endpoint: $MASSBIT_ROUTE_API";
    bash -x $SCRIPT_DIR/blockchain-api/polkadot/polkadot-api-call.sh
  fi
}

#
# $1 - blockchain, $2 - network
#
_execute_performance_testing() {
  export blockchain=$1
  export network=$2
  export PUBLIC_API=$3
  dApiDomain=$(cat "/vars/${blockchain}_${network}_DAPI_DOMAIN")
  dApiAppKey=$(cat "/vars/${blockchain}_${network}_DAPI_APPKEY")
  #dApiUrl=$(cat "/vars/${blockchain}_${network}_DAPI_URL")
  #dApiDomain=$(echo $dApiUrl | cut -d'/' -f3)
  gatewayIP=$(nslookup $dApiDomain 172.24.${NETWORK_NUMBER}.2 | awk -F':' '/Address: [0-9]/{sub(/^ /,"",$2);print $2}')
  export DAPI_DOMAIN=$dApiDomain
  dApiUrl="$protocol://$gatewayIP/$dApiAppKey"
  sed /$DAPI_DOMAIN/d -i /etc/hosts
  echo "$gatewayIP $DAPI_DOMAIN" >> /etc/hosts
  if [ "x$gatewayIP" == "x" ]; then
    echo "Can not resolve ip of $dApiDomain"
    exit 1
  fi
  if [ "$blockchain" == "eth" ]; then
    export MASSBIT_ROUTE_ETHEREUM="$dApiUrl"
    export ANOTHER_ETHEREUM_PROVIDER=${ANOTHER_ETHEREUM_PROVIDER:-$PUBLIC_API}
    echo "Test apis with endpoint: $MASSBIT_ROUTE_ETHEREUM";
    bash -x $SCRIPT_DIR/blockchain-api/ethereum/ethereum-test.sh
    bash -x $SCRIPT_DIR/blockchain-api/ethereum/ethereum-latency-test.sh
    #cd $SCRIPT_DIR/ethereum/flow-test && npm install && node index.js $NUMBER_OF_TESTS $MASSBIT_ROUTE_ETHEREUM $ANOTHER_ETHEREUM_PROVIDER $ETHEREUM_NETWORK $REPORT_DIR $ETHEREUM_PRIVATE_KEY $ETHEREUM_EOA_ADDRESS
  elif [ "$blockchain" == "dot" ]; then
    export MASSBIT_ROUTE_POLKADOT="$dApiUrl"
    export ANOTHER_POLKADOT_PROVIDER=${ANOTHER_POLKADOT_PROVIDER:-$PUBLIC_API}
    echo "Test apis with endpoint: $MASSBIT_ROUTE_POLKADOT";
    bash -x $SCRIPT_DIR/blockchain-api/polkadot/polkadot-test.sh
    bash -x $SCRIPT_DIR/blockchain-api/polkadot/polkadot-latency-test.sh
  fi
}
$@
