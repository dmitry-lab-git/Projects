#!/bin/bash
IP=$1
cd ~/Projects
# правим rxconfig.py на текущий IP
sed -i "s|api_url.*|api_url=\"http://$IP:8000\",|" rxconfig.py
echo "rxconfig -> $(grep api_url rxconfig.py)"
reflex run --env prod
