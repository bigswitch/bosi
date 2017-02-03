#!/bin/bash

# from setup.cfg
#    etc/bosi = etc/bosi_config/config.yaml
#    etc/bosi/t6 = etc/t6/*
#    etc/bosi/t5 = etc/t5/*
#    etc/bosi/rootwrap = etc/rootwrap/*

BASE_PATH='/usr/local/etc/bosi'
if [ -d "/usr/etc" ]
then
  # if /usr/etc exists, then change the BASE_PATH
  BASE_PATH='/usr/etc/bosi'
fi

mkdir -p "$BASE_PATH"

# do not overwrite config file
CONF_PATH=$BASE_PATH'/config.yaml'
if [ ! -e "$CONF_PATH" ]
then
    cp "./etc/bosi_config/config.yaml" "$BASE_PATH"
fi

cp -r "./etc/t5" $BASE_PATH
cp -r "./etc/t6" $BASE_PATH
cp -r "./etc/rootwrap" $BASE_PATH
