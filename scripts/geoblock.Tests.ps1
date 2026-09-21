#!/usr/bin/env pwsh

BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
}

Describe "Geoblock Service" {
    Context "Endpoint" {
        It "Should respond to /geoblock endpoint" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/geoblock"
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Not -BeNullOrEmpty
        }

        It "Should return valid response with Geoblock middleware" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/geoblock"
            $response.Content | Should -Match "Hostname:"
        }

        It "Should route /geoblock to geoblock service" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/geoblock"
            $response.StatusCode | Should -Be 200
        }
    }

    Context "Enrichment" {
        It "Should enrich geo request headers for a public IP (requestHeaderEnrich)" {
            $headers = @{ "X-Forwarded-For" = "8.8.8.8" }
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/geoblock" -Headers $headers
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "X-Geo-Country:\s*US"
            $response.Content | Should -Match "X-Geo-Region:\s*null"
            $response.Content | Should -Match "X-Geo-City:\s*null"
            $response.Content | Should -Match "X-Geo-Asn:\s*null"
            $response.Content | Should -Match "X-Geo-Isp:\s*null"
            $response.Content | Should -Match "X-Geo-Domain:\s*null"
        }

        It "Should enrich PRIVATE country for private IPs when allowPrivate is true" {
            $headers = @{ "X-Forwarded-For" = "192.168.1.100" }
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/geoblock" -Headers $headers
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "X-Geo-Country:\s*PRIVATE"
        }

        It "Should set logStatusDetailHeader on the request (pass:allow_private)" {
            $headers = @{ "X-Forwarded-For" = "192.168.1.100" }
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/geoblock" -Headers $headers
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "X-Geoblock-Decision:\s*pass:allow_private"
        }

        It "Should set logStatusDetailHeader on the request (pass:default_allow)" {
            $headers = @{ "X-Forwarded-For" = "8.8.8.8" }
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/geoblock" -Headers $headers
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "X-Geoblock-Decision:\s*pass:default_allow"
        }

        It "Should not expose geo enrich headers on the HTTP response" {
            $headers = @{ "X-Forwarded-For" = "8.8.8.8" }
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/geoblock" -Headers $headers
            $response.Headers["X-Geo-Country"] | Should -BeNullOrEmpty
            $response.Headers["X-Geoblock-Decision"] | Should -BeNullOrEmpty
        }
    }

    Context "Middleware" {
        It "Should have Geoblock middleware configured" {
            $response = Invoke-TestRequest -Uri "$script:TraefikApiUrl/api/http/middlewares"
            $response.StatusCode | Should -Be 200
            $content = $response.Content | ConvertFrom-Json
            $geoblockMiddleware = $content | Where-Object { $_.name -eq "geoblock@docker" }
            $geoblockMiddleware | Should -Not -BeNull
        }
    }
}
