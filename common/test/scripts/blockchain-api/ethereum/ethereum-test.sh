#! /bin/bash
ROOT_DIR=$(realpath $(dirname $(realpath $0)))
ethereum_api=$(cat $ROOT_DIR/input/ethereum-api.json)
all_test_case="[]"

_generate_test_case() {
  while [[ $(echo $all_test_case | jq length) < $NUMBER_OF_TESTS ]]; do
    latest_block_info=$(
      curl $ANOTHER_ETHEREUM_PROVIDER \
        --silent \
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

    test_case="{
      \"data\": $data,
      \"blockHash\": $block_hash,
      \"blockNumber\": $block_number,
      \"object\": $transaction,
      \"isFullData\": $is_full_data
    }"

    all_test_case=$(echo "$all_test_case" | jq ". += [$test_case]")
    all_test_case=$(echo "$all_test_case" | jq ". | unique")
  done
}

_generate_test_case

#
# $1 - testcase index
# $2 - api index
#
# _check_test_case() {
#   test_case=$(jq .[$1] <<<$all_test_case)
#   apiInd=$2
#   method=$(echo $ethereum_api | jq .[$apiInd].method)
#   params=$(echo $ethereum_api | jq .[$apiInd].params)
#   expect=$(echo $ethereum_api | jq .[$apiInd].expectMatch)
#   mode=$(echo $ethereum_api | jq -r .[$apiInd].mode)
#   if [[ "$TEST_MODE" == "debug" && "$mode" != "$TEST_MODE" ]]; then
#     continue
#   fi
#   new_params="[]"
#
#   for j in $(seq 0 $(($(jq length <<<$params) - 1))); do
#     key=$(echo $params | jq -r .[$j])
#     data=$(echo $test_case | jq .$key)
#     new_params=$(echo "$new_params" | jq ". += [$data]")
#   done
#   body="{\"jsonrpc\": \"2.0\", \"method\": $method, \"params\": $new_params, \"id\": $apiInd}"
#   massbit_http_code=$(curl $MASSBIT_ROUTE_ETHEREUM --silent -L \
#     --header "Host: $DAPI_DOMAIN" \
#     --header "Content-Type: application/json" \
#     --request POST \
#     --data "$body" \
#     -o massbit.out -s -w "%{http_code}")
# }
echo $all_test_case | jq '.' >$ROOT_DIR/input/ethereum-testcase.json

report="[]"
sum_both_error=0
sum_error=0
sum_passed=0
sum_failed=0

for k in $(seq 0 $(($(jq length <<<$all_test_case) - 1))); do
  both_error=0
  error=0
  passed=0
  failed=0

  both_error_report="[]"
  error_report="[]"
  failed_report="[]"
  passed_report="[]"
  test_case=$(jq .[$k] <<<$all_test_case)
  echo "Test case: $test_case";
  for i in $(seq 0 $(($(jq length <<<$ethereum_api) - 1))); do
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
    massbit_http_code=$(curl $MASSBIT_ROUTE_ETHEREUM \
      --silent -L \
      --header "Host: $DAPI_DOMAIN" \
      --header "Content-Type: application/json" \
      --request POST \
      --data "$body" \
      -o massbit.out -s -w "%{http_code}\n")
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

    # response=$(curl $MASSBIT_ROUTE_ETHEREUM \
    #   --silent -L \
    #   --header "Host: $DAPI_DOMAIN" \
    #   --header "Content-Type: application/json" \
    #   --request POST \
    #   --data "$body" | jq -S 'del(.jsonrpc, .id)')
    # expected_response=$(curl $ANOTHER_ETHEREUM_PROVIDER \
    #   --silent \
    #   --header "Content-Type: application/json" \
    #   --request POST \
    #   --data "$body" | jq -S 'del(.jsonrpc, .id)')

    response=$(cat massbit.out | jq -S 'del(.jsonrpc, .id)')
    expected_response=$(cat expected.out | jq -S 'del(.jsonrpc, .id)')
    if [[ $response != *"result"* && $expected_response != *"result"* ]]; then
      both_error=$((both_error + 1))
      both_error_report=$(echo $both_error_report | jq ". += [{\"method\":$method, \"response\":$response, \"expectedResponse\":$expected_response}]")

      echo "==================== BOTH ERROR ==================="
      echo "method : $method"
      echo "response : $response"
      echo "expected_response : $expected_response"
    elif [[ $response != *"result"* ]]; then
      error=$((error + 1))
      error_report=$(echo $error_report | jq ". += [{\"method\":$method, \"response\":$response, \"expectedResponse\":$expected_response}]")

      echo "==================== ERROR ===================="
      echo "method : $method"
      echo "response : $response"
      echo "expected_response : $expected_response"
    elif [[ "$response" != "$expected_response" ]]; then
      if [[ $expect == true ]]; then
        failed=$((failed + 1))
        failed_report=$(echo $failed_report | jq ". += [{\"method\":$method, \"response\":$response, \"expectedResponse\":$expected_response}]")

        echo "==================== OUTPUT DIFF ===================="
        echo "method : $method"
        diff --color <(echo "$response") <(echo "$expected_response")
      else
        passed=$((passed + 1))
        passed_report=$(echo $passed_report | jq ". += [$method]")
      fi
    else
      passed=$((passed + 1))
      passed_report=$(echo $passed_report | jq ". += [$method]")
    fi
  done

  sum=$(($both_error + $error + $failed + $passed))
  test_case_report="{
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
    \"bothError\": {
      \"ratio\": \"$both_error/$sum\",
      \"detail\": $both_error_report
    },
  }"
  report=$(echo $report | jq ". += [$test_case_report]")
  sum_both_error=$(($sum_both_error + $both_error))
  sum_error=$(($sum_error + $error))
  sum_passed=$(($sum_passed + $passed))
  sum_failed=$(($sum_failed + $failed))
done

sum=$(($sum_both_error + $sum_error + $sum_passed + $sum_failed))
report="{
  \"date\": \"$(date)\",
  \"loopCount\": $NUMBER_OF_TESTS,
  \"passed\": \"$sum_passed/$sum\",
  \"failed\": \"$sum_failed/$sum\",
  \"error\": \"$sum_error/$sum\",
  \"bothError\": \"$sum_both_error/$sum\",
  \"result\": $report
}"

if ! [[ -f "$REPORT_DIR/ethereum-report.json" ]]; then
  touch "$REPORT_DIR/ethereum-report.json"
else
  cat /dev/null > "$REPORT_DIR/ethereum-report.json"
fi

echo "[ $report ]" >temp.json
merge_report=$(jq -s add temp.json "$REPORT_DIR/ethereum-report.json")
echo $merge_report | jq '.' >$REPORT_DIR/ethereum-report.json
rm temp.json
