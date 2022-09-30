#! /bin/bash
ROOT_DIR=$(realpath $(dirname $(realpath $0)))
ethereum_api=$(cat $ROOT_DIR/input/ethereum-latency-api.json)

failed=0
passed=0

for i in $(seq 1 $NUMBER_OF_TESTS); do
  for j in $(seq 0 $(($(jq length <<<$ethereum_api) - 1))); do
    method=$(echo $ethereum_api | jq .[$j].method)
    params=$(echo $ethereum_api | jq .[$j].params)

    body="{\"jsonrpc\": \"2.0\", \"method\": $method, \"params\": $params, \"id\": j}"

    massbit_http_code=$(curl $MASSBIT_ROUTE_ETHEREUM \
      --silent -L \
      --header "Host: $DAPI_DOMAIN" \
      --header "Content-Type: application/json" \
      --request POST \
      --data "$body" \
      -o masbit.out -s -w "%{http_code}\n")
    another_provider_http_code=$(curl $ANOTHER_ETHEREUM_PROVIDER \
      --silent \
      --header "Content-Type: application/json" \
      --request POST \
      --data "$body" \
      -o expected.out -s -w "%{http_code}\n")

    if ! [[ "$massbit_http_code" =~ ^20[01]$ && "$another_provider_http_code" =~ ^20[01]$ ]]; then
      error=$((error + 1))
      error_report=$(echo $error_report | jq ". += [{\"method\":$method, \"response\": \"Massbit http code: $massbit_http_code\", \"expectedResponse\": \"Another provider http code: $another_provider_http_code\"}]")

      echo "==================== ERROR ==================="
      echo "method : $method"
      echo "Massbit http code: $massbit_http_code"
      echo "Another provider http code: $another_provider_http_code"
      continue
    fi

    response=$(cat massbit.out | jq -S 'del(.jsonrpc, .id)')
    expected_response=$(cat expected.out | jq -S 'del(.jsonrpc, .id)')

    if [[ "$response" != "$expected_response" ]]; then
      failed=$(($failed + 1))
    else
      passed=$(($passed + 1))
    fi
  done
done

report="{
  \"date\": \"$(date)\",
  \"loopCount\": $NUMBER_OF_TESTS,
  \"passed\": \"$passed/$(($passed + $failed))\",
  \"failed\": \"$failed/$(($passed + $failed))\"
}"

if ! [[ -f "$REPORT_DIR/ethereum-latency-report.json" ]]; then
  touch "$REPORT_DIR/ethereum-latency-report.json"
fi

echo "[ $report ]" >temp.json
merge_report=$(jq -s add temp.json "$REPORT_DIR/ethereum-latency-report.json")
echo $merge_report | jq '.' >$REPORT_DIR/ethereum-latency-report.json
rm temp.json
