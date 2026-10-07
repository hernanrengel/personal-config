#!/bin/sh
# Script para recargar el driver del trackpad de ASUS después de suspender
if [ "$1" = "post" ]; then
    /usr/bin/modprobe -r i2c_hid_acpi i2c_hid
    /usr/bin/modprobe i2c_hid_acpi
fi
