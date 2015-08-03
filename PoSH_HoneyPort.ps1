$port = Read-Host "What port should I listen on?"
$incomingIP = "0.0.0.0"
$iparray = @()
$regex = [regex]"\b(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\b"

# Create listener on specified port
$listener = [System.Net.Sockets.TcpListener]($port)
$listener.Start()

Write-Host "Waiting for connection on port:$port ..."
Write-Host "Press Ctrl+C to stop`n"

$client = [System.Net.Sockets.TcpClient]

While($true) {
    # Wait for remote connection
    $client = $listener.AcceptTcpClient()
    Write-Host "Client connected"
    If ($client.Connected) { 
        # When connection is established grab remote IP address
        $socket = $client.Client
        $incomingIP = $regex.Match($socket.RemoteEndPoint).Value
        $client::Disconnect
        Write-Host "Remote IP to be blocked: $incomingIP"        

        # Update existing firewall rule or create a new one
        If ( Get-NetFirewallRule -DisplayName "Honey Block" ) {
            $iparray = (Get-NetFirewallRule -DisplayName "Honey Block" | Get-NetFirewallAddressFilter).RemoteAddress
            $iparray += $incomingIP
            Get-NetFirewallRule -DisplayName "Honey Block" | Get-NetFirewallAddressFilter | Set-NetFirewallAddressFilter -RemoteAddress $iparray
        } else {
            New-NetFirewallRule -DisplayName "Honey Block" -Protocol TCP -LocalPort $port -RemoteAddress $incomingIP -Action Block
        }
        # Add event in Windows Application log
        Write-EventLog –LogName Application –Source “HoneyPort” –EntryType Information –EventID 9797 -Message "$incomingIP added to Honey Block firewall rule"
    }
}

$listener.Stop()

Write-Host 'Firewall rule named "Honey Block" has been created or updated to include all found IP addresses'