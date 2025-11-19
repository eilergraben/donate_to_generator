# ============================================
# donate_to.ps1 (ASCII only)
# Liest Recipient + Donors + Signatures aus input.txt
# und sendet donate_to-Requests:
# - Logfile
# - Farbige Ausgabe
# - Verzogerung zwischen Requests
# ============================================

# ------------- Konfiguration -------------

$inputFile = ".\input.txt"
$baseUrl   = "https://scavenger.prod.gd.midnighttge.io/donate_to"
$delayBetweenRequests = 3    # Sekunden
$logDir   = ".\logs"

# ------------- Setup -------------

if (!(Test-Path $inputFile)) {
    Write-Host 'ERROR: input.txt nicht gefunden im aktuellen Ordner.' -ForegroundColor Red
    exit
}

if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logFile   = Join-Path $logDir ("donate_to-{0}.log" -f $timestamp)

function Write-Log {
    param(
        [string]$Message
    )
    $ts   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = '{0}' + "`t" + '{1}' -f $ts, $Message
    $line | Out-File -FilePath $logFile -Encoding utf8 -Append
}

Write-Host ("Logfile: {0}" -f $logFile) -ForegroundColor Cyan
Write-Log '==== Start donate_to Script ===='

# ------------- Input parsen -------------

$content = Get-Content $inputFile

# Recipient
$recipientLine = $content | Where-Object { $_ -match '^Recipient address:' } | Select-Object -First 1
if (-not $recipientLine) {
    Write-Host 'ERROR: Keine Zeile mit "Recipient address:" in input.txt gefunden.' -ForegroundColor Red
    Write-Log 'ERROR: Recipient address not found in input file.'
    exit
}

$recipient = $recipientLine.Split(':', 2)[1].Trim()
Write-Host ("Recipient address: {0}" -f $recipient) -ForegroundColor Cyan
Write-Log  ("Recipient: {0}" -f $recipient)
Write-Host ''

# Donor/Signature-Bloecke
$donorEntries = @()

for ($i = 0; $i -lt $content.Count; $i++) {
    $line = $content[$i].Trim()
    if ($line -like 'Donor:*') {
        $donor = $line.Split(':', 2)[1].Trim()

        $signature = $null
        for ($j = $i + 1; $j -lt $content.Count; $j++) {
            $nextLine = $content[$j].Trim()
            if ($nextLine -eq '') { continue }
            if ($nextLine -like 'Signature:*') {
                $signature = $nextLine.Split(':', 2)[1].Trim()
            }
            break
        }

        if (-not $signature) {
            Write-Host ('WARNUNG: Keine Signature-Zeile fuer Donor {0} gefunden - Eintrag wird uebersprungen.' -f $donor) -ForegroundColor Yellow
            Write-Log  ('WARN: Missing signature for donor {0}' -f $donor)
            continue
        }

        $donorEntries += [PSCustomObject]@{
            Donor     = $donor
            Signature = $signature
        }
    }
}

if ($donorEntries.Count -eq 0) {
    Write-Host 'Keine Donor/Signature-Eintraege gefunden.' -ForegroundColor Yellow
    Write-Log  'WARN: No donor entries found.'
    exit
}

Write-Host ("Gefundene Donors: {0}" -f $donorEntries.Count) -ForegroundColor Cyan
Write-Host ''

# ------------- Request-Funktion (ohne Retry) -------------

function Send-DonateRequest {
    param(
        [string]$Recipient,
        [string]$Donor,
        [string]$Signature
    )

    $url  = '{0}/{1}/{2}/{3}' -f $baseUrl, $Recipient, $Donor, $Signature
    $body = '{}'

    Write-Host 'Sende donate_to:' -ForegroundColor White
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
            Write-Host ("     Response: {0}" -f $response.Content)
        }
        else {
            Write-Host ("  -> ERROR (HTTP {0})" -f $statusCode) -ForegroundColor Red
            Write-Host ("     Response: {0}" -f $response.Content)
        }
    }
    catch {
        $ex = $_.Exception
        $msg = $ex.Message
        $code = $null
        if ($ex.Response -and $ex.Response.StatusCode) {
            $code = $ex.Response.StatusCode.value__
        }

        if ($code) {
            Write-Host ("  -> Fehler (HTTP {0}): {1}" -f $code, $msg) -ForegroundColor Red
            Write-Log  ('ERROR: HTTP {0} - {1}' -f $code, $msg)
        }
        else {
            Write-Host ("  -> Fehler: {0}" -f $msg) -ForegroundColor Red
            Write-Log  ('ERROR: {0}' -f $msg)
        }
    }
}

# ------------- Hauptschleife -------------

foreach ($entry in $donorEntries) {
    Send-DonateRequest -Recipient $recipient -Donor $entry.Donor -Signature $entry.Signature

    Write-Host ''
    Write-Host ("Warte {0} Sekunden vor dem naechsten Request..." -f $delayBetweenRequests) -ForegroundColor DarkGray
    Write-Log  ('Delay {0} seconds before next request' -f $delayBetweenRequests)
    Start-Sleep -Seconds $delayBetweenRequests
}

Write-Log '==== Script finished ===='
Write-Host ''
Write-Host ("Fertig. Details siehe Logfile: {0}" -f $logFile) -ForegroundColor Cyan
