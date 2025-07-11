# File: Check-HPWarranty-CSV-GET.ps1

$csvPath = "C:\Users\admin\Documents\serials_and_products.csv"
$outputPath = "C:\Users\admin\Documents"

if (-not (Test-Path -Path $csvPath)) {
    Write-Error "❌ serials_and_products.csv not found at: $csvPath"
    exit
}
$devices = Import-Csv -Path $csvPath
if ($devices.Count -eq 0) {
    Write-Error "❌ serials_and_products.csv is empty!"
    exit
}

if (-not (Test-Path -Path $outputPath)) {
    Write-Error "❌ Output path does not exist: $outputPath"
    exit
}

$output = @()

foreach ($device in $devices) {
    $serial = $device.SerialNumber.Trim()
    $product = $device.ProductNumber.Trim()

    if (-not $serial -or -not $product) {
        Write-Warning "⚠️ Skipping invalid Serial/Product: $serial/$product"
        continue
    }

    Write-Host "🔍 Checking $serial ($product) ..." -ForegroundColor Cyan

    $url = "https://support.hp.com/hp-pps-services/validatewarranty/$serial/$product"
    $headers = @{
        "Accept" = "application/json"
    }

    try {
        $response = Invoke-RestMethod -Uri $url -Method GET -Headers $headers

        if ($response.warrantyDetails) {
            foreach ($w in $response.warrantyDetails) {
                $output += [PSCustomObject]@{
                    SerialNumber    = $serial
                    ProductNumber   = $w.productNumber
                    Description     = $w.description
                    Status          = $w.serviceType
                    StartDate       = $w.startDate
                    EndDate         = $w.endDate
                }
            }
        } else {
            Write-Warning "⚠️ No warranty info for $serial"
            $output += [PSCustomObject]@{
                SerialNumber    = $serial
                ProductNumber   = $product
                Description     = "No data"
                Status          = "Unknown"
                StartDate       = ""
                EndDate         = ""
            }
        }
    }
    catch {
        Write-Warning "❌ Error checking $serial: $_"
        $output += [PSCustomObject]@{
            SerialNumber    = $serial
            ProductNumber   = $product
            Description     = "Error fetching"
            Status          = "Unknown"
            StartDate       = ""
            EndDate         = ""
        }
    }

    Start-Sleep -Seconds 3
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$csvFile = Join-Path $outputPath "HP_Warranty_Results_$timestamp.csv"
$output | Export-Csv -Path $csvFile -NoTypeInformation

Write-Host "`n✅ Done! Results saved to: $csvFile" -ForegroundColor Green
