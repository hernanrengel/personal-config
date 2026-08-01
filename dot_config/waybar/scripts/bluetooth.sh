#!/bin/bash

status=$(bluetoothctl show | grep "Powered" | awk '{print $2}')

if [ "$status" == "yes" ]; then
    device=$(bluetoothctl info | grep "Alias" | awk '{print substr($0, index($0,$2))}')
    if [ -z "$device" ]; then
        echo "{\"text\": \" Not connected\", \"tooltip\": \"Bluetooth is on but no device connected\"}"
    else
        echo "{\"text\": \" $device\", \"tooltip\": \"Connected to $device\"}"
    fi
else
    echo "{\"text\": \" Off\", \"tooltip\": \"Bluetooth is turned off\"}"
fi