#!/usr/bin/env pwsh

BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
}

Describe "CrowdSec Fork Service" {
    Context "Endpoint" {
        It "Should respond to /crowdsecfork endpoint" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/crowdsecfork"
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Not -BeNullOrEmpty
        }

        It "Should return valid response with CrowdSec fork middleware" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/crowdsecfork"
            $response.Content | Should -Match "Hostname:"
        }

        It "Should route /crowdsecfork to crowdsecfork service" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/crowdsecfork"
            $response.StatusCode | Should -Be 200
        }
    }

    Context "Middleware" {
        It "Should have CrowdSec fork middleware configured" {
            $response = Invoke-TestRequest -Uri "$script:TraefikApiUrl/api/http/middlewares"
            $response.StatusCode | Should -Be 200
            $content = $response.Content | ConvertFrom-Json
            $crowdsecForkMiddleware = $content | Where-Object { $_.name -eq "crowdsecfork@docker" }
            $crowdsecForkMiddleware | Should -Not -BeNull
            $crowdsecForkMiddleware.plugin.crowdsecfork | Should -Not -BeNull
        }
    }

    Context "Coexistence with upstream CrowdSec" {
        It "Should serve CrowdSec and CrowdSec fork side by side" {
            $upstream = Invoke-TestRequest -Uri "$script:BaseUrl/crowdsec"
            $fork = Invoke-TestRequest -Uri "$script:BaseUrl/crowdsecfork"
            $upstream.StatusCode | Should -Be 200
            $fork.StatusCode | Should -Be 200
            $upstream.Content | Should -Match "Hostname:"
            $fork.Content | Should -Match "Hostname:"
        }
    }
}
