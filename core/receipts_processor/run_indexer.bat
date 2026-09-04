@echo off
pushd "%~dp0"
chcp 65001 > nul
title Indexer Launcher

echo Starting indexer.py in WSL...
echo ---------------------------------------------------
wsl --cd /home/fujitsu-u745/Projects/core /home/fujitsu-u745/Projects/core/venv/bin/python -m receipts_processor.indexer
echo ---------------------------------------------------
echo Execution completed.

popd
pause
