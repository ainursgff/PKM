# SmartCooks - Auto-detect IP & Flutter Run


param(
    [string]$ip = ""
)

# Auto-detect local IP if not provided
if ($ip -eq "") {
    $ip = (
        Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.InterfaceAlias -notmatch "Loopback" -and
            $_.IPAddress -ne "127.0.0.1" -and
            $_.PrefixOrigin -eq "Dhcp"
        } |
        Select-Object -First 1
    ).IPAddress

    # Fallback: jika DHCP tidak ditemukan, cari manual/well-known
    if (-not $ip) {
        $ip = (
            Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object {
                $_.InterfaceAlias -notmatch "Loopback" -and
                $_.IPAddress -ne "127.0.0.1"
            } |
            Select-Object -First 1
        ).IPAddress
    }
}

if (-not $ip) {
    Write-Host "ERROR: Tidak bisa mendeteksi IP lokal!" -ForegroundColor Red
    Write-Host "Gunakan manual: .\run.ps1 -ip 192.168.x.x" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "  SmartCooks" -ForegroundColor Cyan
Write-Host "  Server IP : $ip" -ForegroundColor Green
Write-Host "  Port      : 3000" -ForegroundColor Green
Write-Host ""

flutter run --dart-define="SERVER_IP=$ip"
