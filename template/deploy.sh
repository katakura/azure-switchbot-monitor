#!/bin/sh

LOCATION=japaneast
RESOURCE_GROUP_NAME=rg-switchbot-monitor
RESOURCE_NAME_POSTFIX=switchbotmon

# https://github.com/OpenWonderLabs/SwitchBotAPI
SWITCHBOT_TOKEN=
SWITCHBOT_SECRET=

az group create \
    -g $RESOURCE_GROUP_NAME \
    -l $LOCATION

az deployment group create \
    -g $RESOURCE_GROUP_NAME \
    --template-file ./deploy.bicep \
    --parameter \
        resourcePostfix=$RESOURCE_NAME_POSTFIX \
        switchbotToken=$SWITCHBOT_TOKEN \
        switchbotSecret=$SWITCHBOT_SECRET
