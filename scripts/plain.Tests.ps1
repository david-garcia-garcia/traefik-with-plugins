#!/usr/bin/env pwsh

BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
}

Describe "Plain Service (No Middleware)" {
    Context "Endpoint" {
        It "Should respond to /plain endpoint" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/plain"
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Not -BeNullOrEmpty
        }

        It "Should return valid whoami response format" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/plain"
            $response.Content | Should -Match "Hostname:"
        }

        It "Should route /plain to plain service" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/plain"
            $response.StatusCode | Should -Be 200
        }
    }

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

    Context "Response Times" {
        It "Should respond to /plain within reasonable time" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/plain"
            $stopwatch.Stop()

            $response.StatusCode | Should -Be 200
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000
        }
    }
}
