# Получаем IP WSL динамически
$wslIp = (wsl -d Ubuntu-22.04 hostname -I 2>$null)
if (-not $wslIp) { $wslIp = (bash -c "hostname -I" | ForEach-Object { $_.Split()[0] }) }
$wslIp = $wslIp.Trim().Split()[0]
Write-Host "WSL IP: $wslIp"

netsh interface portproxy delete v4tov4 listenport=3000 listenaddress=0.0.0.0
netsh interface portproxy delete v4tov4 listenport=8000 listenaddress=0.0.0.0

netsh interface portproxy add v4tov4 listenport=3000 listenaddress=0.0.0.0 connectport=3000 connectaddress=$wslIp
netsh interface portproxy add v4tov4 listenport=8000 listenaddress=0.0.0.0 connectport=8000 connectaddress=$wslIp

netsh interface portproxy show v4tov4
Write-Host "Готово! Открывай http://192.168.43.218:3000"