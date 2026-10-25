param([string]$WIFI_IP)
Write-Host "IP: $WIFI_IP"
netsh interface portproxy reset | Out-Null
netsh interface portproxy add v4tov4 listenport=3000 listenaddress=$WIFI_IP connectport=3000 connectaddress=127.0.0.1
netsh interface portproxy add v4tov4 listenport=8000 listenaddress=$WIFI_IP connectport=8000 connectaddress=127.0.0.1
netsh advfirewall firewall delete rule name="Reflex 3000 8000" | Out-Null
netsh advfirewall firewall add rule name="Reflex 3000 8000" dir=in action=allow protocol=TCP localport=3000,8000 profile=any | Out-Null
netsh interface portproxy show all
