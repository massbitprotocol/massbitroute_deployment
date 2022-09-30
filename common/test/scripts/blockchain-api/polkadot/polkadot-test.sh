#! /bin/bash
ROOT_DIR=$(realpath $(dirname $(realpath $0)))
polkadot_api=$(cat $ROOT_DIR/input/polkadot-api.json)
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

_generate_test_case
echo $all_test_case | jq '.' >$ROOT_DIR/input/polkadot-testcase.json

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

  for i in $(seq 0 $(($(jq length <<<$polkadot_api) - 1))); do
    method=$(echo $polkadot_api | jq .[$i].method)
    params=$(echo $polkadot_api | jq .[$i].params)
    expect=$(echo $polkadot_api | jq .[$i].expect)
    new_params="[]"

    for j in $(seq 0 $(($(jq length <<<$params) - 1))); do
      key=$(echo $params | jq .[$j])
      data=$(echo $test_case | jq ."$key")
      new_params=$(echo "$new_params" | jq ". += [$data]")
    done

    body="{\"id\": 1, \"jsonrpc\": \"2.0\", \"method\": "$method", \"params\": "$new_params"}"

    massbit_http_code=$(curl $MASSBIT_ROUTE_POLKADOT \
      --silent -L \
      --header "Host: $DAPI_DOMAIN" \
      --header "Content-Type: application/json" \
      --request POST \
      --data "$body" \
      -o massbit.out -s -w "%{http_code}\n")
    another_provider_http_code=$(curl $ANOTHER_POLKADOT_PROVIDER \
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
        passed_report=$(echo $passed_report | jq ". += [$method]")
        passed=$((passed + 1))
      fi
    else
      passed_report=$(echo $passed_report | jq ". += [$method]")
      passed=$((passed + 1))
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

echo "====================== RESULT ======================"
echo "Polkadot JSON RPC API"
echo "Both occur error: $sum_both_error"
echo "Error: $sum_error"
echo "Failed: $sum_failed"
echo "Passed: $sum_passed"

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

if ! [[ -f "$REPORT_DIR/polkadot-report.json" ]]; then
  touch "$REPORT_DIR/polkadot-report.json"
fi

echo "[ $report ]" >temp.json
merge_report=$(jq -s add temp.json "$REPORT_DIR/polkadot-report.json")
echo $merge_report | jq '.' >$REPORT_DIR/polkadot-report.json
rm temp.json
