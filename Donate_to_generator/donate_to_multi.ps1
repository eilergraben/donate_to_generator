# ============================================
# donate_to.ps1 (Ein Recipient pro Donor)
# Liest fuer jeden Block Recipient + Donor + Signature
# und sendet einzeln donate_to Requests
# ============================================

$inputFile = ".\input_multi.txt"
$baseUrl   = "https://scavenger.prod.gd.midnighttge.io/donate_to"
$delayBetweenRequests = 3
$logDir   = ".\logs"

# Setup
if (!(Test-Path $inputFile)) {
    Write-Host 'ERROR: input_multi.txt fehlt.' -ForegroundColor Red
    exit
}

if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logFile   = Join-Path $logDir ("donate_to-{0}.log" -f $timestamp)

function Write-Log {
    param([string]$Message)
    $ts   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = '{0}' + "`t" + '{1}' -f $ts, $Message
    $line | Out-File -FilePath $logFile -Encoding utf8 -Append
}

Write-Host ("Logfile: {0}" -f $logFile) -ForegroundColor Cyan
Write-Log "==== Start donate_to Script ===="

# Input-Datei lesen
$content = Get-Content $inputFile

# Alle Eintraege finden
$entries = @()
$currentRecipient = $null
$currentDonor     = $null
$currentSig       = $null

foreach ($line in $content) {
    $trim = $line.Trim()

    if ($trim -like "Recipient:*") {
        $currentRecipient = $trim.Split(":",2)[1].Trim()
    }
    elseif ($trim -like "Donor:*") {
        $currentDonor = $trim.Split(":",2)[1].Trim()
    }
    elseif ($trim -like "Signature:*" -or $trim -like "Signiture:*") {
        $currentSig = $trim.Split(":",2)[1].Trim()

        # Wenn Recipient + Donor + Signature zusammen sind → speichern
        if ($currentRecipient -and $currentDonor -and $currentSig) {
            $entries += [PSCustomObject]@{
                Recipient = $currentRecipient
                Donor     = $currentDonor
                Signature = $currentSig
            }

            # Reset fuer naechsten Block
            $currentRecipient = $null
            $currentDonor     = $null
            $currentSig       = $null
        }
    }
}

if ($entries.Count -eq 0) {
    Write-Host 'ERROR: Keine Eintraege gefunden.' -ForegroundColor Red
    Write-Log 'ERROR: No entries found.'
    exit
}

Write-Host ("Gefundene Eintraege: {0}" -f $entries.Count) -ForegroundColor Cyan
Write-Host ''

function Send-DonateRequest {
    param(
        [string]$Recipient,
        [string]$Donor,
        [string]$Signature
    )

    $url  = '{0}/{1}/{2}/{3}' -f $baseUrl, $Recipient, $Donor, $Signature
    $body = '{}'

    Write-Host "Sende donate_to:"
    Write-Host ("  Recipient: {0}" -f $Recipient)
    Write-Host ("  Donor:     {0}" -f $Donor)
    Write-Host ("  Signature: {0}" -f $Signature)
    Write-Log  ("REQUEST to {0}" -f $url)

    try {
        $response   = Invoke-WebRequest -Uri $url -Method POST -Body $body -ContentType 'application/json' -TimeoutSec 30 -ErrorAction Stop
        $statusCode = $response.StatusCode
        Write-Log   ('Response: HTTP {0} - {1}' -f $statusCode, $response.Content)

        if ($statusCode -ge 200 -and $statusCode -lt 300) {
            Write-Host ("  -> SUCCESS (HTTP {0})" -f $statusCode) -ForegroundColor Green
        }
        else {
            Write-Host ("  -> ERROR (HTTP {0})" -f $statusCode) -ForegroundColor Red
        }
    }
    catch {
        $ex = $_.Exception
        Write-Host ("  -> Fehler: {0}" -f $ex.Message) -ForegroundColor Red
        Write-Log  ("ERROR: {0}" -f $ex.Message)
    }
}

foreach ($entry in $entries) {
    Send-DonateRequest -Recipient $entry.Recipient -Donor $entry.Donor -Signature $entry.Signature

    Write-Host ""
    Write-Host ("Warte {0} Sekunden..." -f $delayBetweenRequests) -ForegroundColor DarkGray
    Write-Log  ("Delay {0} seconds" -f $delayBetweenRequests)
    Start-Sleep -Seconds $delayBetweenRequests
}

Write-Log '==== Script finished ===='
Write-Host ''
Write-Host ("Fertig. Details siehe Logfile: {0}" -f $logFile) -ForegroundColor Cyan
