#!/bin/bash
ROOT_DIR=$(realpath $(dirname $(realpath $0)))
source $ROOT_DIR/../base.sh
SCENARIO_ID="$(echo $RANDOM | md5sum | head -c 5)"
echo '-------------------------------------------------------------'
echo "Run scenario ${BASH_SOURCE[0]} with ID $SCENARIO_ID ---------"
echo '-------------------------------------------------------------'
LOOP=2
for (( c=1; c<=$LOOP; c++ ))
do
   $ROOT_DIR/014_create_then_remove_dot_node.sh
done
