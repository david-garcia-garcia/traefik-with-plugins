#!/usr/bin/env pwsh

BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
}

Describe "ModSecurity Service" {
    Context "Endpoint" {
        It "Should respond to /modsecurity endpoint" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/modsecurity"
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Not -BeNullOrEmpty
        }

        It "Should return valid response with ModSecurity middleware" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/modsecurity"
            $response.Content | Should -Match "Hostname:"
        }

        It "Should route /modsecurity to modsecurity service" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/modsecurity"
            $response.StatusCode | Should -Be 200
        }
    }

    Context "Request body limits" {
        It "Should handle request body smaller than pool threshold (512 bytes)" {
            $bodySize = 512
            $body = New-RequestBodyOfSizeBytes -TargetSizeBytes $bodySize -Prefix ""
            $response = Invoke-SafeWebRequest -Uri "$script:BaseUrl/modsecurity" -Method POST -Body $body -TimeoutSec 30
            $response.StatusCode | Should -Be 200
        }

        It "Should handle request body exactly at pool threshold (1024 bytes)" {
            $bodySize = 1024
            $body = New-RequestBodyOfSizeBytes -TargetSizeBytes $bodySize -Prefix ""
            $response = Invoke-SafeWebRequest -Uri "$script:BaseUrl/modsecurity" -Method POST -Body $body -TimeoutSec 30
            $response.StatusCode | Should -Be 200
        }

        It "Should handle request body larger than pool but smaller than max (2048 bytes)" {
            $bodySize = 2048
            $body = New-RequestBodyOfSizeBytes -TargetSizeBytes $bodySize -Prefix ""
            $response = Invoke-SafeWebRequest -Uri "$script:BaseUrl/modsecurity" -Method POST -Body $body -TimeoutSec 30
            $response.StatusCode | Should -Be 200
        }

        It "Should reject request body larger than max size with 413 (6000 bytes)" {
            $bodySize = 6000
            $body = New-RequestBodyOfSizeBytes -TargetSizeBytes $bodySize -Prefix ""
            $response = Invoke-SafeWebRequest -Uri "$script:BaseUrl/modsecurity" -Method POST -Body $body -TimeoutSec 30
            $response.StatusCode | Should -Be 413
        }
    }

    Context "Block error log" {
        It "Should write a parseable Access denied line to the Apache error log" {
            $before = @(docker logs waf 2>&1 | Select-String -Pattern "ModSecurity: Access denied")
            $null = Test-WafBlocking -Url "$script:BaseUrl/modsecurity?file=../../../../etc/passwd"
            $after = @(docker logs waf 2>&1 | Select-String -Pattern "ModSecurity: Access denied")
            $after.Count | Should -BeGreaterThan $before.Count
            $line = $after[-1].Line
            $line | Should -Match 'ModSecurity: Access denied with code 403'
            $line | Should -Match '\[id "949110"\]'
            $line | Should -Match 'unique_id "[^"]+"'
        }

        It "Should write a parseable Access denied line to the nginx error log" {
            $nginx = docker ps --format "{{.Names}}" | Where-Object { $_ -eq "waf-nginx" }
            if (-not $nginx) {
                Set-ItResult -Skipped -Because "waf-nginx is only in the bench overlay"
                return
            }
            $marker = "blocklog-nginx-$(Get-Random)"
            $before = @(docker logs waf-nginx 2>&1 | Select-String -Pattern "ModSecurity: Access denied")
            $null = Test-WafBlocking -Url "$script:BaseUrl/bench/geo-crowdsec-modsec-nginx?file=../../../../etc/passwd&marker=$marker"
            $after = @(docker logs waf-nginx 2>&1 | Select-String -Pattern "ModSecurity: Access denied")
            $after.Count | Should -BeGreaterThan $before.Count
            $line = $after[-1].Line
            $line | Should -Match 'ModSecurity: Access denied with code 403'
            $line | Should -Match '\[id "949110"\]'
            $line | Should -Match 'unique_id "[^"]+"'
            $line | Should -BeLike "*${marker}*"
        }
    }

    Context "Middleware" {
        It "Should have ModSecurity middleware configured" {
            $response = Invoke-TestRequest -Uri "$script:TraefikApiUrl/api/http/middlewares"
            $response.StatusCode | Should -Be 200
            $content = $response.Content | ConvertFrom-Json
            $modsecurityMiddleware = $content | Where-Object { $_.name -eq "waf@docker" }
            $modsecurityMiddleware | Should -Not -BeNull
        }
    }

    Context "Response Times" {
        It "Should respond to middleware services within reasonable time" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/modsecurity"
            $stopwatch.Stop()

            $response.StatusCode | Should -Be 200
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000
        }
    }
}
