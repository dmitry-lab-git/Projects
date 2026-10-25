#!/bin/bash
DIR=$(cd "$(dirname "$0")" && pwd)
crontab "$DIR/crontab.txt"
echo "Installed:"
crontab -l
