#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Benchmarks compiled (embedded) vs Yaegi (interpreted) middleware stacks.

.DESCRIPTION
    Hits the running app with a shared HttpClient. Five stacks, each measured
    with compiled middlewares and with Yaegi middlewares:

      none                              /plain
      geo                               /bench/geo vs /bench/geo-yaegi
      geo+crowdsec                      /bench/geo-crowdsec vs /bench/geo-crowdsec-yaegi
      geo+crowdsec+modsec (apache)      /bench/geo-crowdsec-modsec vs ...-yaegi
      geo+crowdsec+modsec (nginx)       /bench/geo-crowdsec-modsec-nginx vs ...-nginx-yaegi

    CrowdSec fork uses stream mode with fail-open settings and DISTINCT LAPI
    keys (stream cursor is unique per key + bouncer IP):
      compiled: lapi-key-bench-compiled
      Yaegi:    lapi-key-bench-yaegi

    Brings up the bench overlay (`compose.yaml` + `compose.bench.yaml`) so
    Traefik loads `traefik.bench.yml` (extra Yaegi plugins). Does not stop
    the stack afterwards. `-StartContainers` also passes `--build`.

.PARAMETER Requests
    Timed requests per endpoint per phase (sequential and concurrent). Default 200.

.PARAMETER WarmupRequests
    Untimed warmup requests per endpoint. Default 25.

.PARAMETER Concurrency
    In-flight requests during the concurrent phase. Default 8.

.PARAMETER BaseUrl
    Traefik entrypoint. Default http://localhost:8000

.PARAMETER StartContainers
    Rebuild images while bringing up the bench overlay.

.EXAMPLE
    ./Test-Benchmark.ps1

.EXAMPLE
    ./Test-Benchmark.ps1 -Requests 500 -Concurrency 16
#>

[CmdletBinding()]
param(
    [int]$Requests = 200,
    [int]$WarmupRequests = 25,
    [int]$Concurrency = 8,
    [string]$BaseUrl = "http://localhost:8000",
    [switch]$StartContainers
)

$ErrorActionPreference = "Stop"

if ($Requests -lt 1) { throw "Requests must be >= 1" }
if ($WarmupRequests -lt 0) { throw "WarmupRequests must be >= 0" }
if ($Concurrency -lt 1) { throw "Concurrency must be >= 1" }

. .\helpers.ps1

$Stacks = @(
    @{
        Name          = "none"
        CompiledPath  = "/plain"
        YaegiPath     = "/plain"
        SameEndpoint  = $true
        YaegiWait     = $false
    }
    @{
        Name          = "geo"
        CompiledPath  = "/bench/geo"
        YaegiPath     = "/bench/geo-yaegi"
        SameEndpoint  = $false
        YaegiWait     = $true
    }
    @{
        Name          = "geo+crowdsec"
        CompiledPath  = "/bench/geo-crowdsec"
        YaegiPath     = "/bench/geo-crowdsec-yaegi"
        SameEndpoint  = $false
        YaegiWait     = $true
    }
    @{
        Name          = "geo+crowdsec+modsec (apache)"
        CompiledPath  = "/bench/geo-crowdsec-modsec"
        YaegiPath     = "/bench/geo-crowdsec-modsec-yaegi"
        SameEndpoint  = $false
        YaegiWait     = $true
    }
    @{
        Name          = "geo+crowdsec+modsec (nginx)"
        CompiledPath  = "/bench/geo-crowdsec-modsec-nginx"
        YaegiPath     = "/bench/geo-crowdsec-modsec-nginx-yaegi"
        SameEndpoint  = $false
        CompiledWait  = 90
        YaegiWait     = $true
    }
)

function Write-Step {
    param([string]$Message)
    Write-Host "🔄 $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Get-Percentile {
    param(
        [double[]]$Sorted,
        [double]$Percentile
    )
    if ($Sorted.Count -eq 0) { return 0 }
    $index = [Math]::Min($Sorted.Count - 1, [Math]::Floor(($Sorted.Count - 1) * $Percentile))
    return $Sorted[$index]
}

function New-BenchClient {
    $handler = [System.Net.Http.SocketsHttpHandler]::new()
    $handler.MaxConnectionsPerServer = [Math]::Max(16, $Concurrency)
    $handler.PooledConnectionLifetime = [TimeSpan]::FromMinutes(5)
    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.Timeout = [TimeSpan]::FromSeconds(15)
    return $client
}

function Invoke-TimedGet {
    param(
        [System.Net.Http.HttpClient]$Client,
        [string]$Uri
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $response = $Client.GetAsync($Uri).GetAwaiter().GetResult()
    $sw.Stop()
    $status = [int]$response.StatusCode
    $response.Dispose()
    return @{
        Ms     = $sw.Elapsed.TotalMilliseconds
        Status = $status
        Ok     = ($status -ge 200 -and $status -lt 300)
    }
}

function Wait-ForBenchEndpoint {
    param(
        [System.Net.Http.HttpClient]$Client,
        [string]$Uri,
        [string]$Name,
        [int]$TimeoutSeconds = 60
    )

    Write-Step "Waiting for $Name ($Uri)..."
    $elapsed = 0
    do {
        try {
            $result = Invoke-TimedGet -Client $Client -Uri $Uri
            if ($result.Ok) {
                Write-Success "$Name is ready"
                return
            }
        }
        catch {
            # not ready yet
        }
        Start-Sleep -Seconds 2
        $elapsed += 2
    } while ($elapsed -lt $TimeoutSeconds)

    throw "$Name did not become ready within ${TimeoutSeconds}s: $Uri"
}

function Measure-Sequential {
    param(
        [System.Net.Http.HttpClient]$Client,
        [string]$Uri,
        [int]$Count
    )

    $samples = [System.Collections.Generic.List[double]]::new()
    $failures = 0
    $wall = [System.Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $Count; $i++) {
        try {
            $result = Invoke-TimedGet -Client $Client -Uri $Uri
            if ($result.Ok) {
                $samples.Add($result.Ms)
            }
            else {
                $failures++
            }
        }
        catch {
            $failures++
        }
    }
    $wall.Stop()

    return New-BenchStats -Samples $samples.ToArray() -Failures $failures -WallMs $wall.Elapsed.TotalMilliseconds
}

function Measure-Concurrent {
    param(
        [System.Net.Http.HttpClient]$Client,
        [string]$Uri,
        [int]$Count,
        [int]$InFlight
    )

    $samples = [System.Collections.Generic.List[double]]::new()
    $failBox = [int[]]@(0)
    $remaining = $Count
    $wall = [System.Diagnostics.Stopwatch]::StartNew()

    while ($remaining -gt 0) {
        $batchSize = [Math]::Min($InFlight, $remaining)
        $tasks = [System.Threading.Tasks.Task[]]::new($batchSize)
        $swList = [System.Diagnostics.Stopwatch[]]::new($batchSize)
        for ($i = 0; $i -lt $batchSize; $i++) {
            $swList[$i] = [System.Diagnostics.Stopwatch]::StartNew()
            $tasks[$i] = $Client.GetAsync($Uri)
        }
        [System.Threading.Tasks.Task]::WaitAll($tasks)
        for ($i = 0; $i -lt $batchSize; $i++) {
            $swList[$i].Stop()
            $response = $tasks[$i].Result
            $ok = $response.IsSuccessStatusCode
            $response.Dispose()
            if ($ok) {
                [void]$samples.Add($swList[$i].Elapsed.TotalMilliseconds)
            }
            else {
                $failBox[0]++
            }
        }
        $remaining -= $batchSize
    }
    $wall.Stop()

    return New-BenchStats -Samples $samples.ToArray() -Failures $failBox[0] -WallMs $wall.Elapsed.TotalMilliseconds
}

function New-BenchStats {
    param(
        [double[]]$Samples,
        [int]$Failures,
        [double]$WallMs
    )

    $sorted = @($Samples | Sort-Object)
    $avg = if ($sorted.Count -gt 0) { ($sorted | Measure-Object -Average).Average } else { 0 }
    $rps = if ($WallMs -gt 0) { [Math]::Round(($Samples.Count * 1000.0) / $WallMs, 2) } else { 0 }

    return [pscustomobject]@{
        Count    = $Samples.Count
        Failures = $Failures
        MinMs    = if ($sorted.Count) { [Math]::Round($sorted[0], 2) } else { 0 }
        AvgMs    = [Math]::Round($avg, 2)
        P50Ms    = [Math]::Round((Get-Percentile -Sorted $sorted -Percentile 0.50), 2)
        P95Ms    = [Math]::Round((Get-Percentile -Sorted $sorted -Percentile 0.95), 2)
        P99Ms    = [Math]::Round((Get-Percentile -Sorted $sorted -Percentile 0.99), 2)
        MaxMs    = if ($sorted.Count) { [Math]::Round($sorted[-1], 2) } else { 0 }
        WallMs   = [Math]::Round($WallMs, 2)
        Rps      = $rps
    }
}

function Format-Delta {
    param(
        [double]$Compiled,
        [double]$Yaegi,
        [switch]$HigherIsBetter
    )

    if ($Compiled -eq 0) { return "n/a" }
    $ratio = $Yaegi / $Compiled
    $pct = [Math]::Round(($ratio - 1) * 100, 1)
    if ($HigherIsBetter) {
        if ($Yaegi -lt $Compiled) {
            return "{0}x slower ({1}%)" -f ([Math]::Round($Compiled / [Math]::Max($Yaegi, 0.001), 2)), $pct
        }
        return "{0}x of compiled ({1}%)" -f ([Math]::Round($ratio, 2)), $pct
    }
    if ($Yaegi -gt $Compiled) {
        return "{0}x slower (+{1}%)" -f ([Math]::Round($ratio, 2)), $pct
    }
    return "{0}x of compiled ({1}%)" -f ([Math]::Round($ratio, 2)), $pct
}

function New-StatRow {
    param(
        [string]$Stack,
        [string]$Runtime,
        $Stats
    )

    return [pscustomobject]@{
        Stack   = $Stack
        Runtime = $Runtime
        Avg     = $Stats.AvgMs
        P50     = $Stats.P50Ms
        P95     = $Stats.P95Ms
        P99     = $Stats.P99Ms
        Max     = $Stats.MaxMs
        Rps     = $Stats.Rps
        Fail    = $Stats.Failures
    }
}

try {
    Write-Host ""
    Write-Host "compiled vs Yaegi middleware stacks" -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Cyan
    Write-Host "Requests=$Requests  Warmup=$WarmupRequests  Concurrency=$Concurrency" -ForegroundColor Gray
    Write-Host "Stacks: none | geo | geo+crowdsec | geo+crowdsec+modsec (apache|nginx)" -ForegroundColor Gray
    Write-Host "LAPI keys: compiled=lapi-key-bench-compiled  yaegi=lapi-key-bench-yaegi" -ForegroundColor Gray
    Write-Host ""

    $composeArgs = @("--env-file", "versions.conf", "-f", "compose.yaml", "-f", "compose.bench.yaml", "up", "-d")
    if ($StartContainers) { $composeArgs += "--build" }
    Write-Step "Starting bench overlay (compose.yaml + compose.bench.yaml)..."
    docker compose @composeArgs
    if ($LASTEXITCODE -ne 0) { throw "docker compose up failed" }
    Write-Success "Bench overlay is up"

    $client = New-BenchClient
    $sequential = [ordered]@{}
    $concurrent = [ordered]@{}
    try {
        foreach ($stack in $Stacks) {
            $compiledWait = if ($stack.CompiledWait) { $stack.CompiledWait } else { 60 }
            Wait-ForBenchEndpoint -Client $client -Uri ($BaseUrl + $stack.CompiledPath) -Name "$($stack.Name) compiled" -TimeoutSeconds $compiledWait
            if (-not $stack.SameEndpoint) {
                $waitSeconds = if ($stack.YaegiWait) { 180 } else { 60 }
                Wait-ForBenchEndpoint -Client $client -Uri ($BaseUrl + $stack.YaegiPath) -Name "$($stack.Name) Yaegi" -TimeoutSeconds $waitSeconds
            }
        }

        if ($WarmupRequests -gt 0) {
            Write-Step "Warmup ($WarmupRequests requests per endpoint)..."
            foreach ($stack in $Stacks) {
                $null = Measure-Sequential -Client $client -Uri ($BaseUrl + $stack.CompiledPath) -Count $WarmupRequests
                if (-not $stack.SameEndpoint) {
                    $null = Measure-Sequential -Client $client -Uri ($BaseUrl + $stack.YaegiPath) -Count $WarmupRequests
                }
            }
            Write-Success "Warmup complete"
        }

        Write-Step "Sequential phase ($Requests requests each)..."
        foreach ($stack in $Stacks) {
            Write-Host "  $($stack.Name) compiled ($($stack.CompiledPath))..." -ForegroundColor Gray
            $compiled = Measure-Sequential -Client $client -Uri ($BaseUrl + $stack.CompiledPath) -Count $Requests
            if ($stack.SameEndpoint) {
                $yaegi = $compiled
            }
            else {
                Write-Host "  $($stack.Name) Yaegi ($($stack.YaegiPath))..." -ForegroundColor Gray
                $yaegi = Measure-Sequential -Client $client -Uri ($BaseUrl + $stack.YaegiPath) -Count $Requests
            }
            $sequential[$stack.Name] = @{ compiled = $compiled; yaegi = $yaegi; same = [bool]$stack.SameEndpoint }
        }

        Write-Step "Concurrent phase ($Requests requests, $Concurrency in-flight)..."
        foreach ($stack in $Stacks) {
            Write-Host "  $($stack.Name) compiled ($($stack.CompiledPath))..." -ForegroundColor Gray
            $compiled = Measure-Concurrent -Client $client -Uri ($BaseUrl + $stack.CompiledPath) -Count $Requests -InFlight $Concurrency
            if ($stack.SameEndpoint) {
                $yaegi = $compiled
            }
            else {
                Write-Host "  $($stack.Name) Yaegi ($($stack.YaegiPath))..." -ForegroundColor Gray
                $yaegi = Measure-Concurrent -Client $client -Uri ($BaseUrl + $stack.YaegiPath) -Count $Requests -InFlight $Concurrency
            }
            $concurrent[$stack.Name] = @{ compiled = $compiled; yaegi = $yaegi; same = [bool]$stack.SameEndpoint }
        }
    }
    finally {
        $client.Dispose()
    }

    function Show-Phase {
        param(
            [string]$Title,
            [System.Collections.IDictionary]$Results
        )

        Write-Host ""
        Write-Host $Title -ForegroundColor Cyan
        Write-Host ("-" * $Title.Length) -ForegroundColor Cyan

        $rows = foreach ($stack in $Stacks) {
            $pair = $Results[$stack.Name]
            $compiledLabel = if ($pair.same) { "n/a (no mw)" } else { "compiled" }
            New-StatRow -Stack $stack.Name -Runtime $compiledLabel -Stats $pair.compiled
            if (-not $pair.same) {
                New-StatRow -Stack $stack.Name -Runtime "Yaegi" -Stats $pair.yaegi
            }
        }
        $rows | Format-Table -AutoSize | Out-String | Write-Host

        Write-Host "Yaegi vs compiled" -ForegroundColor Yellow
        $deltas = foreach ($stack in $Stacks) {
            $pair = $Results[$stack.Name]
            if ($pair.same) {
                [pscustomobject]@{
                    Stack = $stack.Name
                    Avg   = "same endpoint"
                    P95   = "same endpoint"
                    Rps   = "same endpoint"
                }
            }
            else {
                [pscustomobject]@{
                    Stack = $stack.Name
                    Avg   = Format-Delta -Compiled $pair.compiled.AvgMs -Yaegi $pair.yaegi.AvgMs
                    P95   = Format-Delta -Compiled $pair.compiled.P95Ms -Yaegi $pair.yaegi.P95Ms
                    Rps   = Format-Delta -Compiled $pair.compiled.Rps -Yaegi $pair.yaegi.Rps -HigherIsBetter
                }
            }
        }
        $deltas | Format-Table -AutoSize | Out-String | Write-Host
    }

    Show-Phase -Title "Sequential" -Results $sequential
    Show-Phase -Title "Concurrent" -Results $concurrent

    $failed = @()
    foreach ($phase in @($sequential, $concurrent)) {
        foreach ($stack in $Stacks) {
            $pair = $phase[$stack.Name]
            if ($pair.compiled.Failures -gt 0 -or $pair.yaegi.Failures -gt 0) {
                $failed += $pair
            }
        }
    }
    if ($failed) {
        Write-Warn "Some requests failed. Results are still shown."
        exit 1
    }

    Write-Host ""
    Write-Success "Benchmark complete"
    exit 0
}
catch {
    Write-Host "❌ $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
