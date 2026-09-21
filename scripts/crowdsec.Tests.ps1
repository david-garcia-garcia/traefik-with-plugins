#!/usr/bin/env pwsh

BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
}

Describe "CrowdSec Service" {
    Context "Endpoint" {
        It "Should respond to /crowdsec endpoint" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/crowdsec"
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Not -BeNullOrEmpty
        }

        It "Should return valid response with CrowdSec middleware" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/crowdsec"
            $response.Content | Should -Match "Hostname:"
        }

        It "Should route /crowdsec to crowdsec service" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/crowdsec"
            $response.StatusCode | Should -Be 200
        }
    }

    Context "Middleware" {
        It "Should have CrowdSec middleware configured" {
            $response = Invoke-TestRequest -Uri "$script:TraefikApiUrl/api/http/middlewares"
            $response.StatusCode | Should -Be 200
            $content = $response.Content | ConvertFrom-Json
            $crowdsecMiddleware = $content | Where-Object { $_.name -eq "crowdsec@docker" }
            $crowdsecMiddleware | Should -Not -BeNull
        }
    }
}
