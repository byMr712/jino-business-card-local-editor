param([string]$SyncUrl)
$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

if ($PSScriptRoot) { $dir = $PSScriptRoot } else { $dir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$bodyPath = Join-Path $dir 'body.txt'
$confPath = Join-Path $dir 'card.json'

function Sync-Card([string]$siteUrl) {
    if ($siteUrl -notmatch '^https?://') { $siteUrl = 'https://' + $siteUrl }
    $siteUrl = $siteUrl.TrimEnd('/')
    Write-Host "  Downloading $siteUrl ..."
    $resp = Invoke-WebRequest -Uri ($siteUrl + '/') -UseBasicParsing -TimeoutSec 25
    $html = $resp.Content
    $i = $html.IndexOf('var bcData')
    if ($i -lt 0) { throw 'page does not look like a Jino business card (no bcData found)' }
    $eq = $html.IndexOf('=', $i)
    $j  = $html.IndexOf('</script>', $eq)
    $json = $html.Substring($eq + 1, $j - $eq - 1).Trim()
    if ($json.EndsWith(';')) { $json = $json.Substring(0, $json.Length - 1) }
    $bc = ConvertFrom-Json $json
    if ([string]::IsNullOrEmpty($bc.text)) { throw 'bcData.text is empty' }

    if (Test-Path -LiteralPath $bodyPath) {
        Copy-Item -LiteralPath $bodyPath -Destination ($bodyPath + '.bak') -Force
        Write-Host '  previous body.txt saved as body.txt.bak'
    }
    [IO.File]::WriteAllText($bodyPath, $bc.text, (New-Object System.Text.UTF8Encoding($false)))

    $cfg = [ordered]@{}
    foreach ($p in $bc.PSObject.Properties) { if ($p.Name -ne 'text') { $cfg[$p.Name] = $p.Value } }
    [IO.File]::WriteAllText($confPath, (ConvertTo-Json $cfg -Depth 6), (New-Object System.Text.UTF8Encoding($false)))
    Write-Host '  body.txt and card.json created.'
}

# ---- first run / re-sync ----
if (-not (Test-Path -LiteralPath $bodyPath)) {
    Write-Host ''
    Write-Host '  ================= FIRST RUN SETUP ================='
    Write-Host '  body.txt not found next to start-preview.bat.'
    Write-Host '  Enter the address of your Jino business card site:'
    Write-Host '  ==================================================='
    if ([string]::IsNullOrWhiteSpace($SyncUrl)) {
        while ($true) {
            $u = Read-Host '  Site URL (empty = cancel)'
            if ([string]::IsNullOrWhiteSpace($u)) { Write-Host 'Cancelled.'; exit 1 }
            try { Sync-Card $u; break }
            catch { Write-Host ("  ERROR: " + $_.Exception.Message); Write-Host '  Please try another URL.' }
        }
    }
    else {
        try { Sync-Card $SyncUrl }
        catch { Write-Host ("  ERROR: " + $_.Exception.Message); exit 1 }
    }
}
elseif ($SyncUrl) {
    try { Sync-Card $SyncUrl }
    catch { Write-Host ("  ERROR: " + $_.Exception.Message); exit 1 }
}

if (-not (Test-Path -LiteralPath $bodyPath)) {
    Write-Host 'ERROR: body.txt not found'
    exit 1
}

function New-PageHtml([string]$BodyHtml, [string]$Ticks) {
    $c = [ordered]@{
        layout      = 'list'
        title       = ''
        text_html   = $true
        userpic     = $null
        bg_color    = '#000000'
        font_color  = '#ffffff'
        no_jinologo = $true
    }
    if (Test-Path -LiteralPath $confPath) {
        try {
            $saved = ConvertFrom-Json ([IO.File]::ReadAllText($confPath))
            foreach ($p in $saved.PSObject.Properties) { $c[$p.Name] = $p.Value }
        } catch {}
    }
    $c['text'] = $BodyHtml
    $json = ConvertTo-Json $c -Compress -Depth 6

    $tpl = @'
<!DOCTYPE html>
<html lang="ru">
<head>
<meta http-equiv="content-type" content="text/html;charset=utf-8">
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<title></title>
<style>html,body{margin:0;padding:0;background:#000000;color:#ffffff;}</style>
</head>
<body>
<div id="root"></div>
<script>var bcData = {CFG};</script>
<script src="https://parking-static.jino.ru/static/businesscard.js?1.45.0" charset="utf-8" onerror="document.getElementById('root').innerHTML=bcData.text;"></script>
<script>
(function () {
    var cur = "{TICKS}";
    function chk() {
        fetch("/~mtime", { cache: "no-store" })
            .then(function (r) { return r.text(); })
            .then(function (t) { if (t.trim() !== cur) { location.reload(); } })
            .catch(function () {});
    }
    setInterval(chk, 500);
    window.addEventListener("focus", chk);
    document.addEventListener("visibilitychange", function () { if (!document.hidden) { chk(); } });
})();
</script>
</body>
</html>
'@
    return $tpl.Replace('{CFG}', $json).Replace('{TICKS}', $Ticks)
}

function Send-Response($stream, [int]$code, [string]$ctype, [byte[]]$payload) {
    $status = '200 OK'
    if ($code -eq 404) { $status = '404 Not Found' }
    $head = "HTTP/1.1 $status`r`nContent-Type: $ctype`r`nContent-Length: $($payload.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n"
    $hb = [System.Text.Encoding]::ASCII.GetBytes($head)
    $stream.Write($hb, 0, $hb.Length)
    if ($payload.Length -gt 0) { $stream.Write($payload, 0, $payload.Length) }
    $stream.Flush()
}

$port     = 8077
$listener = $null
while ($null -eq $listener -and $port -le 8099) {
    try {
        $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $port)
        $listener.Start()
    } catch {
        $listener = $null
        $port++
    }
}
if ($null -eq $listener) {
    Write-Host 'ERROR: ports 8077-8099 are all busy'
    exit 1
}
$url = "http://127.0.0.1:$port/"

Write-Host ''
Write-Host '  ========================================'
Write-Host "  Preview server : $url"
Write-Host "  Source file    : $bodyPath"
Write-Host '  Render         : real businesscard.js (like production)'
Write-Host '  Edit body.txt  -> page reloads automatically (~0.5 s)'
Write-Host '  Existing body.txt is used as-is; it is NEVER'
Write-Host '  overwritten unless you run with a site URL argument'
Write-Host '  (re-sync, old copy saved as body.txt.bak)'
Write-Host '  Stop           -> Ctrl+C or close this window'
Write-Host '  ========================================'
Write-Host ''

if ($env:MR712_NO_BROWSER -ne '1') { Start-Process $url }

while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
        $s  = $client.GetStream()
        $s.ReadTimeout = 5000
        $sr  = New-Object System.IO.StreamReader($s, [System.Text.Encoding]::ASCII)
        $req = $sr.ReadLine()
        $n   = 0
        while ($n -lt 64) {
            $line = $sr.ReadLine()
            if ([string]::IsNullOrEmpty($line)) { break }
            $n++
        }
        $path = '/'
        if ($req) {
            $parts = $req.Split(' ')
            if ($parts.Count -ge 2) { $path = $parts[1] }
        }
        $path = ($path -split '\?')[0]

        if ($path -eq '/~mtime') {
            $ticks = (Get-Item -LiteralPath $bodyPath).LastWriteTimeUtc.Ticks.ToString()
            Send-Response $s 200 'text/plain; charset=utf-8' ([System.Text.Encoding]::UTF8.GetBytes($ticks))
        }
        elseif ($path -eq '/') {
            $body  = [IO.File]::ReadAllText($bodyPath)
            $ticks = (Get-Item -LiteralPath $bodyPath).LastWriteTimeUtc.Ticks.ToString()
            $page  = New-PageHtml -BodyHtml $body -Ticks $ticks
            Send-Response $s 200 'text/html; charset=utf-8' ([System.Text.Encoding]::UTF8.GetBytes($page))
        }
        else {
            Send-Response $s 404 'text/plain' ([System.Text.Encoding]::ASCII.GetBytes('not found'))
        }
    } catch {
        # broken pipe / timeout from browser - ignore, keep serving
    } finally {
        try { $client.Close() } catch {}
    }
}
