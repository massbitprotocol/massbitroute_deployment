#!/usr/bin/env bash
ROOT=$(realpath $(dirname $(realpath $0))/)
source $ROOT/params.sh
_IFS=$IFS

_parse_args() {
  #echo "All params $@";
  ARGS=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      -url|--url)
        url="$2"
        shift # past argument
        shift # past value
        ;;
      -t|--type)
        type="$2"
        shift # past argument
        shift # past value
        ;;
      -d|--domain)
        domain="$2"
        shift # past argument
        shift # past value
        ;;
      -b|--blockchain)
        blockchain="$2"
        shift # past argument
        shift # past value
        ;;
      -n|--network)
        network="$2"
        shift # past argument
        shift # past value
        ;;
      --providerId)
        providerId="$2"
        shift # past argument
        shift # past value
        ;;
      --providerIp)
        providerIp="$2"
        shift # past argument
        shift # past value
        ;;
      --providerName)
        providerName="$2"
        shift # past argument
        shift # past value
        ;;
      --providerKey)
        providerKey="$2"
        shift # past argument
        shift # past value
        ;;
      -p|--path)
        path="$2"
        shift # past argument
        shift # past value
        ;;
      -s|--status)
        status="$2"
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
_login() {
  bearer=$(curl -s --location --request POST "https://portal.$domain/auth/login" --header 'Content-Type: application/json' \
          --data-raw "{\"username\": \"$USERNAME\", \"password\": \"$PASSWORD\"}"| jq  -r ". | .accessToken")

  if [[ "$bearer" == "null" ]]; then
    echo "Getting JWT token: Failed"
    exit 1
  fi

  userId=$(curl -s --location --request GET "https://portal.$domain/user/info" \
  --header "Authorization: Bearer $bearer" \
  --header 'Content-Type: application/json' | jq  -r ". | .id")
  echo "User ID $userId"
}
#
#_get_node_info node {nodeId}
#_get_node_info gateway {gatewayId}
#
_get_node_info() {
  _login
  res=$(curl -s --location --request GET "https://portal.$domain/mbr/$1/$2" \
    --header "Authorization: Bearer  $bearer" \
    --header 'Content-Type: application/json' \
    | jq -r '. | .id, .appKey, .name, .blockchain, .zone, .status, .geo.ip' \
    | sed -z -z "s/\n/,/g")
  IFS=$',' fields=($res)
  nodeId=fields[1]
  nodeKey=fields[2]
  nodeIp=fields[7]
}
_get_dapi_session() {
    #Get sessionUrl
    _dapiURL=$(curl -s -X HEAD -I "$1"   --header 'Content-Type: application/json' | awk -F': ' '/^location:/{gsub(/[\s\r]+$/,"",$2);print $2}')
    #Call sessionUrl to get dapiURL with session
    _dapiURL=$(curl -s -X HEAD -I "$_dapiURL"   --header 'Content-Type: application/json' | awk -F': ' '/^location:/{gsub(/[\s\r]+$/,"",$2);print $2}')
    echo "$_dapiURL"
}

_test_data_source() {
    response=$(curl -o /dev/null -s -w "%{http_code}:%{time_total}s\n" --request POST "$1" \
      --header 'Content-Type: application/json' \
      --data-raw '{
        "jsonrpc": "2.0",
        "method": "eth_getBlockByNumber",
        "params": [
            "latest",
            false
        ],
        "id": 1
    }' -k)
    echo "Datasource response: $response"
    # if [[ "$dapi_response_code" != "200" ]]; then
    #   echo "Calling dAPI: Failed"
    #   exit 1
    # fi
}
_test_node_api() {
    response=$(curl -o /dev/null -s -w "%{http_code}:%{time_total}s\n" --request POST "https://$1" \
      --header 'Content-Type: application/json' \
      --header "Host: $2.node.mbr.$domain" \
      --header "X-Api-Key: $3" \
      --data-raw '{
        "jsonrpc": "2.0",
        "method": "eth_getBlockByNumber",
        "params": [
            "latest",
            false
        ],
        "id": 1
    }' -k -vv)
    echo "Node response: $response"
    # if [[ "$dapi_response_code" != "200" ]]; then
    #   echo "Calling dAPI: Failed"
    #   exit 1
    # fi
}

_test_gateway_api() {
    response=$(curl -o /dev/null -s -w "%{http_code}:%{time_total}s\n" --request POST "https://$1" \
      --header 'Content-Type: application/json' \
      --header "Host: $2.gw.mbr.$domain" \
      --header "X-Api-Key: $3" \
      --data-raw '{
        "jsonrpc": "2.0",
        "method": "eth_getBlockByNumber",
        "params": [
            "latest",
            false
        ],
        "id": 1
    }' -k -vv)
    echo "Gateway response: $response"
}
_test_dapi() {
    response=$(curl -o /dev/null -s -w "%{http_code}:%{time_total}s\n" --request POST "$1" \
      --header 'Content-Type: application/json' \
      --data-raw '{
        "jsonrpc": "2.0",
        "method": "eth_getBlockByNumber",
        "params": [
            "latest",
            false
        ],
        "id": 1
    }' -L)
    echo "Dapi response: $response"
    # if [[ "$response_code" != "200" ]]; then
    #   echo "Calling dAPI: Failed"
    #   exit 1
    # fi
    # echo "Calling dAPI: Pass"
}
# $1 url
# $2 type: node, gateway, dAPI
# $3 rate
# $4 provider id
# $5 provider appkey
# $6 provider name
# $7 blockchain
_single_benchmark() {
  echo "Single benchmark params $@"
  _parse_args "$@"
  echo "Call wrk with param $url -- $type $domain $blockchain $providerId $providerKey"
  if [ "$type" == "dapi" ]; then
      $wrk_dir/wrk -t$thread -c$connection -d$duration -R$rate --latency -T$timeout -s $wrk_dir/dapi.lua $url -- $domain $blockchain > $output
  elif [ "$type" == "node" ]; then
      $wrk_dir/wrk -t$thread -c$connection -d$duration -R$rate --latency -T$timeout -s $wrk_dir/node.lua $url -- $domain $blockchain $providerId $providerKey > $output
  else
      $wrk_dir/wrk -t$thread -c$connection -d$duration -R$rate --latency -T$timeout -s $wrk_dir/gateway.lua $url -- $domain $blockchain $providerId $providerKey $path > $output
  fi

  latency_row=$(cat $output  | grep -A 4 "Thread Stats   Avg      Stdev     Max   +/- Stdev" | sed -n "2 p")
  IFS='    ' read -ra latency <<< "$latency_row"
  req_sec_row=$(cat $output  | grep -A 4 "Thread Stats   Avg      Stdev     Max   +/- Stdev" | sed -n "3 p")
  IFS='    ' read -ra req_sec <<< "$req_sec_row"
  hdrhistogram50=$(cat $output  | grep -A 4 "Latency Distribution (HdrHistogram - Recorded Latency)" | sed -n "2 p")
  IFS='    ' read -ra hdrhistogram50 <<< "$hdrhistogram50"
  hdrhistogram75=$(cat $output  | grep -A 4 "Latency Distribution (HdrHistogram - Recorded Latency)" | sed -n "3 p")
  IFS='    ' read -ra hdrhistogram75 <<< "$hdrhistogram75"
  hdrhistogram90=$(cat $output  | grep -A 4 "Latency Distribution (HdrHistogram - Recorded Latency)" | sed -n "4 p")
  IFS='    ' read -ra hdrhistogram90 <<< "$hdrhistogram90"
  hdrhistogram99=$(cat $output  | grep -A 4 "Latency Distribution (HdrHistogram - Recorded Latency)" | sed -n "5 p")
  IFS='    ' read -ra hdrhistogram99 <<< "$hdrhistogram99"
  #Request rates
  IFS=':'
  _rate=$(cat $output | grep "Requests/sec")
  read -ra fields <<< "$_rate"
  requestRate=$(echo ${fields[1]} | tr -d " ")
  #Transfer rates
  _rate=$(cat $output | grep "Transfer/sec")
  read -ra fields <<< "$_rate"
  transferRate=$(echo ${fields[1]} | tr -d " ")
  addr_row=$(cat $output | grep -m 1 "thread addr:")
  addr=($addr_row)
  IFS=$_IFS
  localIp=$(curl icanhazip.com)
  result=(${addr[1]} $requestRate $transferRate ${hdrhistogram90[1]} ${hdrhistogram99[1]} ${latency_row[1]} ${latency_row[2]} ${latency_row[3]} ${req_sec[1]})
  echo "${result[@]}"

  if [ "$type" == "dapi" ]; then
    curl "$dapiFormResult" --silent >/dev/null \
      --data "entry.721172135=$localIp&entry.140673538=${addr[1]}&entry.1670770464=$client&entry.1360977389=$blockchain-$network&entry.1089136036=$duration&entry.770798199=$requestRate&entry.796670045=$transferRate&entry.144814654=${latency[1]}&entry.542037870=${latency[2]}&entry.1977269592=${latency[3]}&entry.1930208986=${hdrhistogram75[1]}&entry.1037348686=${hdrhistogram90[1]}&entry.131454525=${hdrhistogram99[1]}&entry.1567713965=${req_sec[1]}" \


  elif [ "$type" == "node" ]; then
    curl "$nodeFormResult" --silent >/dev/null \
      --data "entry.721172135=$providerIp&entry.140673538=$providerId&entry.1145125196=$providerName&entry.1670770464=$client&entry.1360977389=$blockchain-$network&entry.1089136036=$duration&entry.770798199=$requestRate&entry.796670045=$transferRate&entry.144814654=${latency[1]}&entry.542037870=${latency[2]}&entry.1977269592=${latency[3]}&entry.1930208986=${hdrhistogram75[1]}&entry.1037348686=${hdrhistogram90[1]}&entry.131454525=${hdrhistogram99[1]}&entry.1567713965=${req_sec[1]}" \
      -d entry.1577564002=$status \
      -d entry.1262797340=$localIp \
      -d entry.385380233=$path
  else
    curl "$gwFormResult" --silent >/dev/null \
      --data "entry.721172135=$providerIp&entry.140673538=$providerId&entry.1145125196=$providerName&entry.1670770464=$client&entry.1360977389=$blockchain-$network&entry.1089136036=$duration&entry.770798199=$requestRate&entry.796670045=$transferRate&entry.144814654=${latency[1]}&entry.542037870=${latency[2]}&entry.1977269592=${latency[3]}&entry.1930208986=${hdrhistogram75[1]}&entry.1037348686=${hdrhistogram90[1]}&entry.131454525=${hdrhistogram99[1]}&entry.1567713965=${req_sec[1]}" \
      -d entry.1709266694=$status \
      -d entry.17092450=$localIp \
      -d entry.962643896=$path

  fi
  cat $output
  #if [ "$formResult" == "x" ]; then
  #  formResult=https://docs.google.com/forms/d/1gzn6skD5MH7D3cyIsv8qcbkbox6QRcxzhkT9AomXE8o/formResponse
  #fi
  #curl "$formResult" --silent >/dev/null \
  #  --data "entry.721172135=$type&entry.140673538=$providerId&entry.1145125196=$providerName&entry.1670770464=$client&entry.1360977389=$blockchain&entry.1089136036=$duration&entry.770798199=$requestRate&entry.796670045=$transferRate&entry.144814654=${latency[1]}&entry.542037870=${latency[2]}&entry.1977269592=${latency[3]}&entry.1930208986=${hdrhistogram75[1]}&entry.1037348686=${hdrhistogram90[1]}&entry.131454525=${hdrhistogram99[1]}&entry.1567713965=${req_sec[1]}"

}

# $1 url
# $2 type: node, gateway, dAPI
# $3 blockchain
# $4
# $4 provider id
# $5 provider appkey
# $6 provider name
_benchmark() {
  _parse_args "$@"
  for rate in "${rates[@]}"
    do
      args=(-url $url -t $type -r $rate -b $blockchain -n $network)
      echo "${args[@]}"
      if [ "x$providerId" != "x" ]; then
        args+=(--providerId $providerId)
      fi
      if [ "x$providerName" != "x" ]; then
        args+=(--providerName $providerName)
      fi
      if [ "x$path" != "x" ]; then
        args+=(-p $path)
      fi
      #_single_benchmark -url $url -t $type -r $rate -b $blockchain -n $network --providerId $providerId --providerName $providerName
      _single_benchmark "${args[@]}"
    done
}
# $1 - Type
_ping_nodes() {
  if [ "$1" == "node" ]; then
    type=node
  else
    type=gateway
  fi
  nodes=$(curl -s --location --request GET "https://portal.$domain/mbr/$type/list/verify" --header "Authorization: $bearerAdmin")
  len=$(echo $nodes | jq length)
  ((len=len-1))
  for i in $( seq 0 $len )
  do
    node=$(echo "$nodes" | jq ".[$i]" | jq ". | .id, .ip, .appKey, .zone, .name, .status" | sed -z "s/\"//g; s/\n/,/g;")
    _IFS=$IFS
    IFS=$',' fields=($node);
    IFS=$_IFS
    nodeZone=${fields[3]^^}
    zone=${zone^^}
    #if [ "$zone" == "$nodeZone" ]; then
    if [ "x${fields[1]}" != "x" ]; then
      url="http://${fields[1]}/ping"
      response=$(timeout 1 curl -s --location --request GET "$url"\
        --header "X-Api-Key: ${fields[2]}" \
        --header "Host: ${fields[0]}.$1.mbr.$domain")
      if [ "x$response" == "xpong" ]; then
        echo "ping $type $url success"
      else
        formPingResult=https://docs.google.com/forms/d/1tKpz_j_JS0LlDjiTOy44ym-4GWVNi9tLs1gzKSGcrA0/formResponse
        if [ "x$formPingResult" != "x" ]; then
          curl "$formPingResult"  --silent >/dev/null \
          --data "entry.2056253786=$client&entry.2038576234=$1&entry.814843005=$blockchain&entry.1408740996=$network&entry.1585210645=${fields[4]}&entry.1395047356=${fields[0]}&entry.2030347037=${fields[1]}&entry.1230249318=fail"
        fi
        echo "ping $type $url fail"
        echo ${fields[@]};
      fi
    fi
  done
}
_benchmark_ping() {
  if [ "$1" == "node" ]; then
    type=node
  else
    type=gateway
  fi
  rate=10
  statuses=("staked" "verified")
  for status in ${statuses[@]}; do
    nodes=$(curl -s --location --request GET "https://portal.$domain/mbr/$type/list/verify?status=$status" --header "Authorization: $bearerAdmin")
    len=$(echo $nodes | jq length)
    ((len=len-1))
    for i in $( seq 0 $len )
      do
        node=$(echo "$nodes" | jq ".[$i]" | jq ". | .id, .ip, .appKey, .zone, .name, .blockchain" | sed -z "s/\n/,/g;")
        IFS=$',' fields=($node);
        IFS=$_IFS

        zone=${zone^^}
        ip=$(echo ${fields[1]} | sed -z "s/\"//g;")
        appKey=$(echo ${fields[2]} | sed -z "s/\"//g;")
        nodeZone=${fields[3]^^}
        providerId=$(echo ${fields[0]} | sed -z "s/\"//g;")
        providerName=${fields[4]}
        blockchain=$(echo ${fields[5]} | sed -z "s/\"//g;")
        if [ "$zone" == "$nodeZone" ]; then
          echo "Benchmarking node ${fields[@]}"
          url="https://$ip/ping"
          _single_benchmark -url $url -t $type -r $rate --providerId $providerId --providerKey $appKey --providerName $providerName -b $blockchain
        fi
      done
  done
}
# $1 - rate
_benchmark_nodes() {
  nodeFormResult=https://docs.google.com/forms/d/1W8NkP1ZLlFi1Nu9ikQpKS0fIBhVpFHtRHMgde3o8580/formResponse
  statuses=("staked" "verified" "investigate" "investigate_fail" "reported")
  for status in ${statuses[@]}; do
    nodes=$(curl -s --location --request GET "https://portal.$domain/mbr/node/list/verify?status=$status" --header "Authorization: $bearerAdmin")
    len=$(echo $nodes | jq length)
    ((len=len-1))
    for i in $( seq 0 $len )
    do
      node=$(echo "$nodes" | jq ".[$i]" | jq ". | .id, .appKey, .zone, .name, .blockchain, .ip, .status" | sed -z "s/\n/,/g;" )
      IFS=$',' fields=($node);
      IFS=$_IFS
      id=$(echo ${fields[0]} | sed -z "s/\"//g;")
      appKey=$(echo ${fields[1]} | sed -z "s/\"//g;")
      nodeZone=$(echo ${fields[2]^^} | sed -z "s/\"//g;")
      name=${fields[3]}
      blockchain=$(echo ${fields[4]} | sed -z "s/\"//g;")
      ip=$(echo ${fields[5]} | sed -z "s/\"//g;")
      #status=$(echo ${fields[6]} | sed -z "s/\"//g;")
      rate=$1
      zone=${zone^^}
      if [[ "$zone" == "$nodeZone" ]]; then
        echo "Benchmarking node ${fields[@]}"
        if [ "x$rate" == "x" ]; then
          _benchmark -url "https://$ip" -t node --providerId $id --providerIp $ip --providerKey $appKey --providerName $name -b $blockchain -s $status --path ""
          _benchmark -url "https://$ip" -t node --providerId $id --providerIp $ip --providerKey $appKey --providerName $name -b $blockchain -s $status --path "_test_20k"
        else
          _single_benchmark -url "https://$ip" -t node --providerId $id --providerIp $ip --providerKey $appKey --providerName $name -b $blockchain -s $status -r $rate --path ""
          _single_benchmark -url "https://$ip" -t node --providerId $id --providerIp $ip --providerKey $appKey --providerName $name -b $blockchain -s $status -r$ rate --path "_test_20k"
        fi
      fi
    done
  done
}
_benchmark_gateways() {
  gwFormResult=https://docs.google.com/forms/d/1gzn6skD5MH7D3cyIsv8qcbkbox6QRcxzhkT9AomXE8o/formResponse
  statuses=("staked" "verified" "investigate" "investigate_fail" "reported")
  for status in ${statuses[@]}; do
    nodes=$(curl -s --location --request GET "https://portal.$domain/mbr/gateway/list/verify?status=$status" --header "Authorization: $bearerAdmin")
    len=$(echo $nodes | jq length)
    ((len=len-1))
    for i in $( seq 0 $len )
    do
      node=$(echo "$nodes" | jq ".[$i]" | jq ". | .id, .appKey, .zone, .name, .blockchain, .ip, .status" | sed -z "s/\n/,/g;")
      IFS=$',' fields=($node);
      IFS=$_IFS
      id=$(echo ${fields[0]} | sed -z "s/\"//g;")
      appKey=$(echo ${fields[1]} | sed -z "s/\"//g;")
      nodeZone=$(echo ${fields[2]^^} | sed -z "s/\"//g;")
      name=${fields[3]}
      blockchain=$(echo ${fields[4]} | sed -z "s/\"//g;")
      ip=$(echo ${fields[5]} | sed -z "s/\"//g;")
      status=$(echo ${fields[6]} | sed -z "s/\"//g;")
      zone=${zone^^}
      if [[ "$zone" == "$nodeZone" ]]; then
        echo "Benchmarking gateway ${fields[@]}"
        _benchmark -url "https://$ip" -t gateway --providerId $id --providerIp $ip --providerKey $appKey --providerName $name -b $blockchain -s $status --path ""
        _benchmark -url "https://$ip" -t gateway --providerId $id --providerIp $ip --providerKey $appKey --providerName $name -b $blockchain -s $status --path "_test_20k"
      fi
    done
  done
}

_benchmark_dapis() {
  dapiFormResult=https://docs.google.com/forms/d/1UwqhL_b58IPxoyvHjZd9FQr22VYmMfw0V-YYV5wBS6w/formResponse
  #Get project info
  projects=$(curl -s --location --request GET "https://portal.$domain/mbr/d-apis/project/list" --header "Authorization: Bearer $bearer")
  len=$(echo $projects | jq length)
  ((len=len-1))
  for i in $( seq 0 $len )
  do
    project=$(echo "$projects" | jq ".[$i]" | jq ". | .id, .name, .blockchain, .network, .status, .quota, .usage" | sed -z "s/\n/,/g;")
    IFS=$',' fields=($project);
      if [[ "${fields[0]}" == "$projectId" ]]; then
        blockchain=${fields[2]}
        network=${fields[3]}
        break
      fi
    IFS=$_IFS
  done
  #Get random dapi in projectId
  dApis=$(curl -s --location --request GET "https://portal.$domain/mbr/d-apis/list/$projectId?limit=100" \
    --header "Authorization: Bearer $bearer" | jq  -r ". | .dApis")
  len=$(echo $dApis | jq length)
  min=0
  if (( len > 0 )); then
    randomInd=$(($RANDOM % $len + $min))
    dApi=$(echo "$dApis" | jq ".[$randomInd]" | jq ". | .appId, .appKey" | sed -z "s/\"//g; s/\n/,/g; s/,$//g;s/,/.$blockchain-$network.$domain\//g")
    _dapiURL="https://$dApi"
    echo "Test dapi $_dapiURL"
    _test_dapi $_dapiURL
    echo "Benchmarking dapi $_dapiURL ..."
    _benchmark -url "$_dapiURL" -t dapi -b $blockchain -n $network -d $domain
  fi
}

_run() {
  _login
  #echo "Get dapiURL with session"
  #_dapiURL=$(_get_dapi_session $dapiURL)  #Temporary disable session
  _benchmark_dapis
  #_ping_nodes node;
  #_ping_nodes gw
  _benchmark_nodes
  _benchmark_gateways
}

_benchmark_gw() {
  _login
  gwFormResult=https://docs.google.com/forms/d/1gzn6skD5MH7D3cyIsv8qcbkbox6QRcxzhkT9AomXE8o/formResponse
  nodes=$(curl -s --location --request GET "https://portal.$domain/mbr/gateway/list/verify" --header "Authorization: $bearerAdmin")
  len=$(echo $nodes | jq length)
  ((len=len-1))
  for i in $( seq 0 $len )
  do
    node=$(echo "$nodes" | jq ".[$i]" | jq ". | .id, .appKey, .zone, .name, .blockchain, .ip, .status" | sed -z "s/\n/,/g;")
    IFS=$',' fields=($node);
    IFS=$_IFS
    id=$(echo ${fields[0]} | sed -z "s/\"//g;")
    appKey=$(echo ${fields[1]} | sed -z "s/\"//g;")
    nodeZone=$(echo ${fields[2]^^} | sed -z "s/\"//g;")
    name=${fields[3]}
    blockchain=$(echo ${fields[4]} | sed -z "s/\"//g;")
    ip=$(echo ${fields[5]} | sed -z "s/\"//g;")
    status=$(echo ${fields[6]} | sed -z "s/\"//g;")
    zone=${zone^^}
    if [[ "$id" == "$1" ]]; then
      echo "Benchmarking gateway ${fields[@]}"
      _benchmark -url "https://$ip" -t gateway --providerId $id --providerIp $ip --providerKey $appKey --providerName $name -b $blockchain -s $status --path ""
      _benchmark -url "https://$ip" -t gateway --providerId $id --providerIp $ip --providerKey $appKey --providerName $name -b $blockchain -s $status --path "_test_20k"
      break
    fi
  done
}
$@
