#!/usr/bin/env pwsh

BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
}

Describe "Traefik API Tests" {
    Context "API Endpoints" {
        It "Should provide raw data endpoint" {
            $response = Invoke-TestRequest -Uri "$script:TraefikApiUrl/api/rawdata"
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Not -BeNullOrEmpty
        }

        It "Should provide routers information" {
            $response = Invoke-TestRequest -Uri "$script:TraefikApiUrl/api/http/routers"
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Not -BeNullOrEmpty
        }

        It "Should provide services information" {
            $response = Invoke-TestRequest -Uri "$script:TraefikApiUrl/api/http/services"
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Not -BeNullOrEmpty
        }

        It "Should provide middlewares information" {
            $response = Invoke-TestRequest -Uri "$script:TraefikApiUrl/api/http/middlewares"
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Traefik WebUI Dashboard Tests" {
    Context "Dashboard Accessibility" {
        It "Should respond to dashboard endpoint" {
            $response = Invoke-TestRequest -Uri "$script:TraefikApiUrl/dashboard/"
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Not -BeNullOrEmpty
        }

        It "Should serve dashboard HTML content" {
            $response = Invoke-TestRequest -Uri "$script:TraefikApiUrl/dashboard/"
            $response.Content | Should -Match "html|HTML|Traefik"
        }

        It "Should redirect root to dashboard" {
            $response = Invoke-TestRequest -Uri "$script:TraefikApiUrl/"
            ($response.StatusCode -eq 200 -or ($response.StatusCode -ge 300 -and $response.StatusCode -lt 400)) | Should -Be $true
        }

        It "Should serve dashboard assets" {
            $response = Invoke-TestRequest -Uri "$script:TraefikApiUrl/dashboard/"
            $response.StatusCode | Should -Be 200
            ($response.Content.Length -gt 10) | Should -Be $true
        }
    }

    Context "Dashboard API Integration" {
        It "Should provide API data for dashboard" {
            $response = Invoke-TestRequest -Uri "$script:TraefikApiUrl/api/overview"
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Not -BeNullOrEmpty
        }

        It "Should provide version information for dashboard" {
            $response = Invoke-TestRequest -Uri "$script:TraefikApiUrl/api/version"
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "version|Version"
        }
    }
}

Describe "Basic Routing Tests" {
    Context "Unknown paths" {
        It "Should return 404 for unknown paths" {
            try {
                Invoke-TestRequest -Uri "$script:BaseUrl/nonexistent"
                $false | Should -Be $true -Because "Should have thrown an exception for 404"
            }
            catch {
                $_.Exception.Response.StatusCode | Should -Be "NotFound"
            }
        }
    }
}

Describe "Basic Performance Tests" {
    Context "Response Times" {
        It "Should respond to Traefik API within reasonable time" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $response = Invoke-TestRequest -Uri "$script:TraefikApiUrl/api/rawdata"
            $stopwatch.Stop()

            $response.StatusCode | Should -Be 200
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 2000
        }
    }
}

Describe "Traefik Container Health Tests" {
    Context "Container Logs and Error Checking" {
        It "Should have no errors in Traefik container logs" {
            $logs = docker logs traefik-with-plugins-traefik-1 2>&1
            $errorLines = $logs | Where-Object { $_ -match "ERR " }

            if ($errorLines) {
                Write-Host "Found ERROR messages in Traefik logs:" -ForegroundColor Yellow
                $errorLines | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
            }

            $errorLines.Count | Should -Be 0 -Because "Traefik should start without any ERROR level messages"
        }

        It "Should have successful plugin loading messages" {
            $logs = docker logs traefik-with-plugins-traefik-1 2>&1
            $successMessages = $logs | Where-Object {
                $_ -match "Building embedded plugin" -or
                $_ -match "Using embedded plugin" -or
                $_ -match "Embedded plugin.*completed"
            }

            if ($successMessages) {
                Write-Host "Found plugin loading success messages:" -ForegroundColor Green
                $successMessages | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
            }

            $successMessages | Should -Not -BeNullOrEmpty -Because "Should see embedded plugin loading messages"
        }
    }
}
