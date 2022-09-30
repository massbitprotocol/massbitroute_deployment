#!/bin/bash
ROOT_DIR=$(dirname $(realpath $0))
network_number=[[NETWORK_NUMBER]]
ENV_DIR=[[ENV_DIR]]
PROVIDERID=$1
PATH_SCHEDULER=$ENV_DIR/scheduler/log/err.log
PATH_WORKER01=$ENV_DIR/fisherman/worker01/log/err.log
PATH_WORKER02=$ENV_DIR/fisherman/worker02/log/err.log
PATTERN_SENDJOB="Send request handle_jobs to worker WorkerInfo"
PATTERN_SENDRESULT="Body content: "
WORKER01_RTT=$(cat $PATH_SCHEDULER | grep -E "$PATTERN_SENDJOB.*worker01.*RoundTripTime" | grep $PROVIDERID | sed -n '$=')
WORKER01_LATEST_BLOCK=$(cat $PATH_SCHEDULER | grep -E "$PATTERN_SENDJOB.*worker01.*LatestBlock" | grep $PROVIDERID | sed -n '$=')
WORKER01_BENCHMARK=$(cat $PATH_SCHEDULER | grep -E "$PATTERN_SENDJOB.*worker01.*Benchmark" | grep $PROVIDERID | sed -n '$=')
WORKER01_WEBSOCKET=$(cat $PATH_SCHEDULER | grep -E "$PATTERN_SENDJOB.*worker01.*Websocket" | grep $PROVIDERID | sed -n '$=')

WORKER02_RTT=$(cat $PATH_SCHEDULER | grep -E "$PATTERN_SENDJOB.*worker02.*RoundTripTime" | grep $PROVIDERID | sed -n '$=')
WORKER02_LATEST_BLOCK=$(cat $PATH_SCHEDULER | grep -E "$PATTERN_SENDJOB.*worker02.*LatestBlock" | grep $PROVIDERID | sed -n '$=')
WORKER02_BENCHMARK=$(cat $PATH_SCHEDULER | grep -E "$PATTERN_SENDJOB.*worker02.*Benchmark" | grep $PROVIDERID | sed -n '$=')
WORKER02_WEBSOCKET=$(cat $PATH_SCHEDULER | grep -E "$PATTERN_SENDJOB.*worker02.*Websocket" | grep $PROVIDERID | sed -n '$=')

if [ "$WORKER01_RTT" -gt 0 ]; then
  WORKER01_RTT_RESULT=cat $PATH_WORKER01 | grep -E "$PATTERN_SENDJOB.*reporter.*Benchmark" | grep $PROVIDERID
fi
