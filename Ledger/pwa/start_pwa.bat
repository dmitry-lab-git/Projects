@echo off
wsl -d Ubuntu -e bash -c "cd ~/Projects/Ledger/pwa && source .venv/bin/activate && reflex run"
pause
