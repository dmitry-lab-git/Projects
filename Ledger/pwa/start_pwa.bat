@echo off
C:
cd %USERPROFILE%
wsl -d Ubuntu -e bash -c "cd ~/Projects/Ledger/pwa && source .venv/bin/activate && reflex run"
pause