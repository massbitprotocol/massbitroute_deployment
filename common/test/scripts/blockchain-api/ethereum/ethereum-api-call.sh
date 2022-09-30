#! /bin/bash
ROOT_DIR=$(realpath $(dirname $(realpath $0)))
ethereum_api=$(cat $ROOT_DIR/input/ethereum-api.json)
all_test_case="[]"

_generate_test_case() {
    latest_block_info=$(
      curl $MASSBIT_ROUTE_API \
        --silent -L \
        --header 'Content-Type: application/json' \
        --request POST \
        --data '{
        "id": 1,
        "jsonrpc": "2.0",
        "method": "eth_getBlockByNumber",
        "params": [ "latest", true ]
      }'
    )

    data=$(echo $latest_block_info | jq '.result.sha3Uncles')
    block_hash=$(echo $latest_block_info | jq '.result.transactions[0].blockHash')
    block_number=$(echo $latest_block_info | jq '.result.transactions[0].blockNumber')
    transaction=$(echo $latest_block_info | jq '.result.transactions[0] | del(.input, .accessList, .r, .s, .v, .chainId, .maxFeePerGas, .maxPriorityFeePerGas, .type, .nonce, .blockHash, .blockNumber)')
    is_full_data=false

    if [[ "$block_hash" = "null" ]]; then
      continue
    fi

    export TEST_CASE="{
      \"data\": $data,
      \"blockHash\": $block_hash,
      \"blockNumber\": $block_number,
      \"object\": $transaction,
      \"isFullData\": $is_full_data
    }"
    all_test_case=$(echo "$all_test_case" | jq ". += [$TEST_CASE]")
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
  echo "Latest block info: $TEST_CASE";
  for i in $(seq 0 $(($(jq length <<<$ethereum_api) - 1))); do
    #_check_test_case $k $i
    method=$(echo $ethereum_api | jq .[$i].method)
    params=$(echo $ethereum_api | jq .[$i].params)
    expect=$(echo $ethereum_api | jq .[$i].expectMatch)
    mode=$(echo $ethereum_api | jq -r .[$i].mode)
    if [[ "$TEST_MODE" != "debug" || "$mode" == "$TEST_MODE" ]]; then  
      new_params="[]"

      for j in $(seq 0 $(($(jq length <<<$params) - 1))); do
        key=$(echo $params | jq -r .[$j])
        data=$(echo $TEST_CASE | jq .$key)
        new_params=$(echo "$new_params" | jq ". += [$data]")
      done

      body="{\"jsonrpc\": \"2.0\", \"method\": $method, \"params\": $new_params, \"id\": $i}"
      http_code=$(curl $MASSBIT_ROUTE_API -L \
        --header "Host: $DAPI_DOMAIN" \
        --header "Content-Type: application/json" \
        --request POST \
        --data "$body" \
        -o $REPORT_DIR/api.out -s -w "%{http_code}\n")


      if ! [[ "$http_code" =~ ^20[01]$ ]]; then
        error=$((error + 1))
        error_report=$(echo $error_report | jq ". += [{\"method\":$method, \"response\": \"Http code: $http_code\"}]")

        echo "==================== ERROR ==================="
        echo "method : $method"
        echo "Http code: $http_code"
        continue
      fi
      cat $REPORT_DIR/api.out
      response=$(cat $REPORT_DIR/api.out | jq -S 'del(.jsonrpc, .id)')
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
echo $all_test_case | jq '.' > $ROOT_DIR/ethereum-latest-blocks.json
echo $report | jq '.' > $REPORT_DIR/ethereum-apis-call-report.json
