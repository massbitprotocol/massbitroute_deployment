#! /bin/bash
ROOT_DIR=$(realpath $(dirname $(realpath $0)))
ethereum_api=$(cat $ROOT_DIR/input/polkadot-api.json)
all_test_case="[]"

_generate_test_case() {
  while [[ $(jq length <<<$all_test_case) != $NUMBER_OF_TESTS ]]; do
    latest_block_info=$(curl $ANOTHER_POLKADOT_PROVIDER \
      -H "Content-Type: application/json" \
      -s -X POST \
      --data '{
      "jsonrpc": "2.0",
      "method": "chain_getHeader",
      "params": [],
      "id": 1 }')

    block_number=$(echo $latest_block_info | jq '.result.number')
    block_hash=$(curl $ANOTHER_POLKADOT_PROVIDER \
      -H "Content-Type: application/json" \
      -s -X POST \
      --data "{
      \"jsonrpc\": \"2.0\",
      \"method\": \"chain_getBlockHash\",
      \"params\": ["$block_number"],
      \"id\": 1 }" | jq '.result')
    extrinsic=$(curl $ANOTHER_POLKADOT_PROVIDER \
      -H "Content-Type: application/json" \
      -s -X POST \
      --data "{
      \"jsonrpc\": \"2.0\",
      \"method\": \"chain_getBlock\",
      \"params\": ["$block_hash"],
      \"id\": 1 }" | jq '.result.block.extrinsics[0]')

    if ! [[ -n "$extrinsic" || -n "$block_hash" || -n "$block_number" ]]; then
      continue
    fi

    test_case="{\"blockHash\":$block_hash, \"blockNumber\":$block_number, \"extrinsic\": $extrinsic}"
    all_test_case=$(echo "$all_test_case" | jq ". += [$test_case]")
    all_test_case=$(echo "$all_test_case" | jq ". | unique")
  done
}

all_reports="[]"
sum_error=0
sum_passed=0
sum_failed=0

for (( k = 0; k<$LOOP; k++ )); do
  error=0
  passed=0
  failed=0

  error_report="[]"
  failed_report="[]"
  passed_report="[]"
  _generate_test_case
  echo "Latest block info: $test_case";
  for i in $(seq 0 $(($(jq length <<<$polkadot_api) - 1))); do
    #_check_test_case $k $i
    method=$(echo $ethereum_api | jq .[$i].method)
    params=$(echo $ethereum_api | jq .[$i].params)
    expect=$(echo $ethereum_api | jq .[$i].expectMatch)
    mode=$(echo $ethereum_api | jq -r .[$i].mode)
    if [[ "$TEST_MODE" == "debug" && "$mode" != "$TEST_MODE" ]]; then
      continue
    fi
    new_params="[]"

    for j in $(seq 0 $(($(jq length <<<$params) - 1))); do
      key=$(echo $params | jq -r .[$j])
      data=$(echo $test_case | jq .$key)
      new_params=$(echo "$new_params" | jq ". += [$data]")
    done

    body="{\"jsonrpc\": \"2.0\", \"method\": $method, \"params\": $new_params, \"id\": $i}"
    http_code=$(curl $MASSBIT_ROUTE_API \
      --silent -L \
      --header "Host: $DAPI_DOMAIN" \
      --header "Content-Type: application/json" \
      --request POST \
      --data "$body" \
      -o api.out -s -w "%{http_code}\n")


    if ! [[ "$http_code" =~ ^20[01]$ ]]; then
      error=$((error + 1))
      error_report=$(echo $error_report | jq ". += [{\"method\":$method, \"response\": \"Http code: $http_code\"}]")

      echo "==================== ERROR ==================="
      echo "method : $method"
      echo "Http code: $http_code"
      continue
    fi

    response=$(cat api.out | jq -S 'del(.jsonrpc, .id)')
    if [[ $response != *"result"* ]]; then
      error=$((error + 1))
      error_report=$(echo $error_report | jq ". += [{\"method\":$method, \"response\":$response}]")

      echo "==================== ERROR ===================="
      echo "method : $method"
      echo "response : $response"

    else
      passed=$((passed + 1))
      passed_report=$(echo $passed_report | jq ". += [$method]")
    fi
  done

  sum=$(($error + $failed + $passed))
  report="{
    \"passed\": {
      \"ratio\": \"$passed/$sum\",
      \"detail\": $passed_report
    },
    \"failed\": {
      \"ratio\": \"$failed/$sum\",
      \"detail\": $failed_report
    },
    \"error\": {
      \"ratio\": \"$error/$sum\",
      \"detail\": $error_report
    },
  }"
  all_reports=$(echo $all_reports | jq ". += [$report]")
  sum_error=$(($sum_error + $error))
  sum_passed=$(($sum_passed + $passed))
  sum_failed=$(($sum_failed + $failed))

done

sum=$(($sum_error + $sum_passed + $sum_failed))
report="{
  \"date\": \"$(date)\",
  \"loopCount\": $LOOP,
  \"passed\": \"$sum_passed/$sum\",
  \"failed\": \"$sum_failed/$sum\",
  \"error\": \"$sum_error/$sum\",
  \"result\": $all_reports
}"

# if ! [[ -f "$REPORT_DIR/ethereum-report.json" ]]; then
#   touch "$REPORT_DIR/ethereum-report.json"
# else
#   cat /dev/null > "$REPORT_DIR/ethereum-report.json"
# fi
#
# if ! [[ -f "$REPORT_DIR/ethereum-apis-call-report.json" ]]; then
#   touch "$REPORT_DIR/ethereum-apis-call-report.json"
# else
#   cat /dev/null > "$REPORT_DIR/ethereum-apis-call-report.json"
# fi
echo $all_test_case | jq '.' > $ROOT_DIR/polkadot-latest-blocks.json
echo $report | jq '.' > $REPORT_DIR/polkadot-apis-call-report.json
