#!/usr/bin/env pwsh

# Integration Tests for Traefik with Plugins
# These tests verify that the Traefik setup with plugins is working correctly

BeforeAll {
    # Test configuration
    $script:BaseUrl = "http://localhost:8000"
    $script:TraefikApiUrl = "http://localhost:8080"
    $script:TestTimeout = 30
    
    # Helper function to make HTTP requests with retry logic
    function Invoke-TestRequest {
        param(
            [string]$Uri,
            [string]$Method = "GET",
            [int]$TimeoutSec = 10,
            [int]$MaxRetries = 3
        )
        
        $retryCount = 0
        do {
            try {
                return Invoke-WebRequest -Uri $Uri -Method $Method -TimeoutSec $TimeoutSec -UseBasicParsing
            }
            catch {
                $retryCount++
                if ($retryCount -eq $MaxRetries) {
                    throw $_
                }
                Start-Sleep -Seconds 2
            }
        } while ($retryCount -lt $MaxRetries)
    }
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

Describe "Service Endpoint Tests" {
    Context "Plain Service (No Middleware)" {
        It "Should respond to /plain endpoint" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/plain"
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Not -BeNullOrEmpty
        }

        It "Should return valid whoami response format" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/plain"
            $response.Content | Should -Match "Hostname:"
        }
    }

    Context "ModSecurity Service" {
        It "Should respond to /modsecurity endpoint" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/modsecurity"
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Not -BeNullOrEmpty
        }

        It "Should return valid response with ModSecurity middleware" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/modsecurity"
            $response.Content | Should -Match "Hostname:"
        }
    }

    Context "Geoblock Service" {
        It "Should respond to /geoblock endpoint" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/geoblock"
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Not -BeNullOrEmpty
        }

        It "Should return valid response with Geoblock middleware" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/geoblock"
            $response.Content | Should -Match "Hostname:"
        }
    }

    Context "CrowdSec Service" {
        It "Should respond to /crowdsec endpoint" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/crowdsec"
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Not -BeNullOrEmpty
        }

        It "Should return valid response with CrowdSec middleware" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/crowdsec"
            $response.Content | Should -Match "Hostname:"
        }
    }
}

Describe "Plugin Configuration Tests" {
    Context "Middleware Plugins" {
        It "Should have ModSecurity middleware configured" {
            $response = Invoke-TestRequest -Uri "$script:TraefikApiUrl/api/http/middlewares"
            $response.StatusCode | Should -Be 200
            $content = $response.Content | ConvertFrom-Json
            $modsecurityMiddleware = $content | Where-Object { $_.name -eq "modsecurity@docker" }
            $modsecurityMiddleware | Should -Not -BeNull
        }

        It "Should have Geoblock middleware configured" {
            $response = Invoke-TestRequest -Uri "$script:TraefikApiUrl/api/http/middlewares"
            $response.StatusCode | Should -Be 200
            $content = $response.Content | ConvertFrom-Json
            $geoblockMiddleware = $content | Where-Object { $_.name -eq "geoblock@docker" }
            $geoblockMiddleware | Should -Not -BeNull
        }

        It "Should have CrowdSec middleware configured" {
            $response = Invoke-TestRequest -Uri "$script:TraefikApiUrl/api/http/middlewares"
            $response.StatusCode | Should -Be 200
            $content = $response.Content | ConvertFrom-Json
            $crowdsecMiddleware = $content | Where-Object { $_.name -eq "crowdsec@docker" }
            $crowdsecMiddleware | Should -Not -BeNull
        }
    }
}

Describe "Basic Routing Tests" {
    Context "Path-based Routing" {
        It "Should route /plain to plain service" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/plain"
            $response.StatusCode | Should -Be 200
        }

        It "Should route /modsecurity to modsecurity service" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/modsecurity"
            $response.StatusCode | Should -Be 200
        }

        It "Should route /geoblock to geoblock service" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/geoblock"
            $response.StatusCode | Should -Be 200
        }

        It "Should route /crowdsec to crowdsec service" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/crowdsec"
            $response.StatusCode | Should -Be 200
        }

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
        It "Should respond to /plain within reasonable time" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/plain"
            $stopwatch.Stop()
            
            $response.StatusCode | Should -Be 200
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000
        }

        It "Should respond to middleware services within reasonable time" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/modsecurity"
            $stopwatch.Stop()
            
            $response.StatusCode | Should -Be 200
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000
        }

        It "Should respond to Traefik API within reasonable time" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $response = Invoke-TestRequest -Uri "$script:TraefikApiUrl/api/rawdata"
            $stopwatch.Stop()
            
            $response.StatusCode | Should -Be 200
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 2000
        }
    }
}

Describe "Header Tests" {
    Context "Response Headers" {
        It "Should include Traefik headers in responses" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/plain"
            $response.Headers.Keys | Should -Contain "Date"
        }

        It "Should handle basic HTTP headers correctly" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/plain"
            $response.Headers.Keys | Should -Contain "Content-Type"
        }
    }
} 