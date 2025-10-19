\
param(
  [string]$HostName = "localhost"
)

$Base = "http://{0}:8080" -f $HostName

Write-Host "== health =="
Invoke-WebRequest -UseBasicParsing -Uri "$Base/" | Out-Null

Write-Host "== hmac sign =="
$r = Invoke-WebRequest -UseBasicParsing -Method Head -Uri "$Base/sign"
$r.Headers.GetValues("X-Time") | ForEach-Object { "X-Time: $_" }
$r.Headers.GetValues("X-Sign") | ForEach-Object { "X-Sign: $_" }

Write-Host "== report raw =="
Invoke-WebRequest -UseBasicParsing -Uri "$Base/report" | Select-Object -ExpandProperty Content

Write-Host "== report filtered (redacted) =="
Invoke-WebRequest -UseBasicParsing -Uri "$Base/report-filtered" | Select-Object -ExpandProperty Content

Write-Host "== api gate (requires x-api-key) =="
try {
  $r1 = Invoke-WebRequest -UseBasicParsing -Uri "$Base/api/hello" -Headers @{ "x-api-key"="demo" }
  $r1.Content
} catch { $_.Exception.Response.StatusCode }

Write-Host "-- with cookie user=stable123"
$sc = New-Object System.Net.CookieContainer
$uri = New-Object System.Uri("$Base/api/hello")
$c = New-Object System.Net.Cookie("user", "stable123")
$sc.Add($uri, $c)
$handler = New-Object System.Net.Http.HttpClientHandler
$handler.UseCookies = $true
$handler.CookieContainer = $sc
$client = New-Object System.Net.Http.HttpClient($handler)
$client.DefaultRequestHeaders.Add("x-api-key", "demo")
($client.GetAsync($uri).Result.Content.ReadAsStringAsync().Result)

Write-Host "-- with cookie user=canary1"
$sc2 = New-Object System.Net.CookieContainer
$c2 = New-Object System.Net.Cookie("user", "canary1")
$sc2.Add($uri, $c2)
$handler2 = New-Object System.Net.Http.HttpClientHandler
$handler2.UseCookies = $true
$handler2.CookieContainer = $sc2
$client2 = New-Object System.Net.Http.HttpClient($handler2)
$client2.DefaultRequestHeaders.Add("x-api-key", "demo")
($client2.GetAsync($uri).Result.Content.ReadAsStringAsync().Result)
