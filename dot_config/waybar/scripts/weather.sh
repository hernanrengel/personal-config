#!/bin/bash
# Consulta temperatura en La Paz, Bolivia
WEATHER=$(curl -s 'https://wttr.in/La_Paz?format=1')
echo "{\"text\": \"$WEATHER\"}"
