#!/bin/bash
ENV_DIR=[[ENV_DIR]]
export gateway=$(cat $ENV_DIR/vars/gateway)
export node=$(cat $ENV_DIR/vars/node)
export stat=$(cat $ENV_DIR/vars/stat)
export git=$(cat $ENV_DIR/vars/git)
export chain=$(cat $ENV_DIR/vars/chain)
export fisherman=$(cat $ENV_DIR/vars/fisherman)
export staking=$(cat $ENV_DIR/vars/staking)
export portal=$(cat $ENV_DIR/vars/portal)
export web=$(cat $ENV_DIR/vars/web)
export api=$(cat $ENV_DIR/vars/api)
export gwman=$(cat $ENV_DIR/vars/gwman)
export session=$(cat $ENV_DIR/vars/session)
