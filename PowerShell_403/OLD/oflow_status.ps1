param(
    [string]$Action = "status"
)

$Token = "vlQUoNuhD2aL8QOd1Ujg"
$BaseUrl = "http://ntinfo403:8010"

$Headers = @{
    Authorization = "Bearer $Token"
}

switch ($Action) {
    "status" {
        Invoke-RestMethod "$BaseUrl/status" -Headers $Headers
    }

    "pool" {
        Invoke-RestMethod "$BaseUrl/pool" -Headers $Headers
    }

    "restart" {
        Invoke-RestMethod "$BaseUrl/restart" -Method Post -Headers $Headers
    }

    default {
        Write-Host "Neznámá akce: $Action"
        Write-Host "Použití:"
        Write-Host ".\oflow.ps1 status"
        Write-Host ".\oflow.ps1 pool"
        Write-Host ".\oflow.ps1 restart"
    }
}