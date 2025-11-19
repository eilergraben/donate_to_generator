# ============================================
# donate_to_multi.ps1
# Liest fuer jeden Block:
#   Entry X
#   Recipient: <addr>
#   Donor:     <addr>
#   Signature: <hex>
# und sendet einzeln donate_to Requests.
# ============================================

# ------------- Konfiguration -------------

$inputFile = ".\Input_multi.txt"   # oder .\input_multi.txt, unter Windows egal
$baseUrl   = "https://scavenger.prod.gd.midnighttge.io/donate_to"
$delayBetweenRequests = 3          # Sekunden
$logDir   = ".\logs"

# ------------- Setup -------------

if (!(Test-Path $inputFile)) {
    Write-Host 'ERROR: Input_multi.txt nicht gefunden im aktuellen Ordner.' -ForegroundColor Red
    exit
}

if (!(Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logFile   = Join-Path $logDir ("donate_to_multi-{0}.log" -f $timestamp)

function Write-Log {
    param([string]$Message)
    $ts   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = '{0}' + "`t" + '{1}' -f $ts, $Message
    $line | Out-File -FilePath $logFile -Encoding utf8 -Append
}

Write-Host ("Logfile: {0}" -f $logFile) -ForegroundColor Cyan
Write-Log  '==== Start donate_to_multi Script ===='

# ------------- Input parsen -------------

$content = Get-Content $inputFile

$entries = @()
$current = $null

foreach ($rawLine in $content) {
    $line = $rawLine.Trim()

    if ($line -eq "") {
        continue
    }

    # Neuer Block: "Entry X"
    if ($line -match '^Entry\s+\d+') {
        # vorherigen Block abschließen
        if ($current -ne $null) {
            if ($current.Recipient -and $current.Donor -and $current.Signature) {
                $entries += [PSCustomObject]$current
            }
            else {
                Write-Host ("WARNUNG: Unvollstaendiger Block {0} wird uebersprungen." -f $current.Entry) -ForegroundColor Yellow
                Write-Log  ("WARN: Incomplete entry {0} skipped (Recipient='{1}', Donor='{2}', Signature='{3}')" -f $current.Entry, $current.Recipient, $current.Donor, $current.Signature)
            }
        }

        # neuen Block anlegen
        $current = @{
            Entry     = $line
            Recipient = $null
            Donor     = $null
            Signature = $null
        }
        continue
    }

    # Wenn noch kein "Entry X" begonnen hat, ignorieren
    if ($current -eq $null) { continue }

    if ($line -like 'Recipient:*') {
        $current.Recipient = $line.Split(':', 2)[1].Trim()
        continue
    }

    if ($line -like 'Donor:*') {
        $current.Donor = $line.Split(':', 2)[1].Trim()
        continue
    }

    if ($line -like 'Signature:*') {
        $current.Signature = $line.Split(':', 2)[1].Trim()
        continue
    }
}

# letzten Block auch noch einsammeln
if ($current -ne $null) {
    if ($current.Recipient -and $current.Donor -and $current.Signature) {
        $entries += [PSCustomObject]$current
    }
    else {
        Write-Host ("WARNUNG: Unvollstaendiger Block {0} wird uebersprungen." -f $current.Entry) -ForegroundColor Yellow
        Write-Log  ("WARN: Incomplete entry {0} skipped (Recipient='{1}', Donor='{2}', Signature='{3}')" -f $current.Entry, $current.Recipient, $current.Donor, $current.Signature)
    }
}

if ($entries.Count -eq 0) {
    Write-Host 'Keine vollstaendigen Recipient/Donor/Signature-Eintraege gefunden.' -ForegroundColor Yellow
    Write-Log  'WARN: No complete entries found.'
    exit
}

Write-Host ("Gefundene vollstaendige Eintraege: {0}" -f $entries.Count) -ForegroundColor Cyan
Write-Log  ("INFO: Parsed {0} complete entries" -f $entries.Count)
Write-Host ''

# ------------- Request-Funktion -------------

function Send-DonateRequest {
    param(
        [string]$Recipient,
        [string]$Donor,
        [string]$Signature,
        [string]$EntryName
    )

    $url  = '{0}/{1}/{2}/{3}' -f $baseUrl, $Recipient, $Donor, $Signature
    $body = '{}'

    Write-Host ("Sende donate_to fuer {0}:" -f $EntryName) -ForegroundColor White
    Write-Host ("  Recipient: {0}" -f $Recipient)
    Write-Host ("  Donor:     {0}" -f $Donor)
    Write-Host ("  Signature: {0}" -f $Signature)
    Write-Log  ("REQUEST ({0}) to {1}" -f $EntryName, $url)

    try {
        $response   = Invoke-WebRequest -Uri $url -Method POST -Body $body -ContentType 'application/json' -TimeoutSec 30 -ErrorAction Stop
        $statusCode = $response.StatusCode
        Write-Log   ('Response ({0}): HTTP {1} - {2}' -f $EntryName, $statusCode, $response.Content)

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
            Write-Log  ('ERROR ({0}): HTTP {1} - {2}' -f $EntryName, $code, $msg)
        }
        else {
            Write-Host ("  -> Fehler: {0}" -f $msg) -ForegroundColor Red
            Write-Log  ('ERROR ({0}): {1}' -f $EntryName, $msg)
        }
    }
}

# ------------- Hauptschleife -------------

foreach ($entry in $entries) {
    $entryName = $entry.Entry
    Send-DonateRequest -Recipient $entry.Recipient -Donor $entry.Donor -Signature $entry.Signature -EntryName $entryName

    Write-Host ''
    Write-Host ("Warte {0} Sekunden vor dem naechsten Request..." -f $delayBetweenRequests) -ForegroundColor DarkGray
    Write-Log  ('Delay {0} seconds before next request' -f $delayBetweenRequests)
    Start-Sleep -Seconds $delayBetweenRequests
}

Write-Log '==== Script finished ===='
Write-Host ''
Write-Host ("Fertig. Details siehe Logfile: {0}" -f $logFile) -ForegroundColor Cyan
