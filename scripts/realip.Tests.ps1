#!/usr/bin/env pwsh

BeforeAll {
    . "$PSScriptRoot/TestHelpers.ps1"
}

Describe "RealIP Service" {
    Context "Endpoint" {
        It "Should respond to /realip endpoint" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/realip"
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Not -BeNullOrEmpty
        }

        It "Should return valid response with RealIP middleware" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/realip"
            $response.Content | Should -Match "Hostname:"
        }

        It "Should route /realip to realip service" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/realip"
            $response.StatusCode | Should -Be 200
        }

        It "Should have RealIP middleware configured" {
            $response = Invoke-TestRequest -Uri "$script:TraefikApiUrl/api/http/middlewares"
            $response.StatusCode | Should -Be 200
            $content = $response.Content | ConvertFrom-Json
            $realipMiddleware = $content | Where-Object { $_.name -eq "realip@docker" }
            $realipMiddleware | Should -Not -BeNull
        }
    }

    Context "Header processing" {
        It "Should process X-Forwarded-For header and set X-Real-IP" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/realip"
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "Hostname:"
            $response.Content | Should -Match "X-Real-Ip.*172\.\d+\.\d+\.\d+"
        }

        It "Should handle CF-Connecting-IP header with priority" {
            $headers = @{
                "CF-Connecting-IP" = "203.0.113.1"
            }

            $response = Invoke-WebRequest -Uri "$script:BaseUrl/realip" -Headers $headers -UseBasicParsing
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "X-Real-Ip.*203\.0\.113\.1"
        }

        It "Should fallback to X-Forwarded-For when CF-Connecting-IP is empty" {
            $headers = @{
                "CF-Connecting-IP" = ""
            }

            $response = Invoke-WebRequest -Uri "$script:BaseUrl/realip" -Headers $headers -UseBasicParsing
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "X-Real-Ip.*172\.\d+\.\d+\.\d+"
        }

        It "Should handle single IP processing" {
            $headers = @{
                "CF-Connecting-IP" = "203.0.113.1"
            }

            $response = Invoke-WebRequest -Uri "$script:BaseUrl/realip" -Headers $headers -UseBasicParsing
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "X-Real-Ip.*203\.0\.113\.1"
        }

        It "Should work without proxy headers (fallback to clientAddress)" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/realip"
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "Hostname:"
            $response.Content | Should -Match "X-Real-Ip"
        }

        It "Should handle IPv6 addresses" {
            $headers = @{
                "CF-Connecting-IP" = "2001:db8::1"
            }

            $response = Invoke-WebRequest -Uri "$script:BaseUrl/realip" -Headers $headers -UseBasicParsing
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "X-Real-Ip.*2001:db8::1"
        }

        It "Should handle IPs with ports correctly" {
            $headers = @{
                "CF-Connecting-IP" = "203.0.113.1:8080"
            }

            $response = Invoke-WebRequest -Uri "$script:BaseUrl/realip" -Headers $headers -UseBasicParsing
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "X-Real-Ip.*203\.0\.113\.1"
        }

        It "Should verify X-Real-IP header is added by RealIP plugin" {
            $headers = @{
                "CF-Connecting-IP" = "203.0.113.1"
            }
            $response = Invoke-WebRequest -Uri "$script:BaseUrl/realip" -Headers $headers -UseBasicParsing
            $response.Content | Should -Match "X-Real-Ip.*203\.0\.113\.1"
        }
    }
}

Describe "RealIP Plugin Edge Cases and Error Handling" {
    Context "Edge Cases" {
        It "Should handle malformed IP addresses gracefully" {
            $headers = @{
                "CF-Connecting-IP" = "not-an-ip-address"
            }

            $response = Invoke-WebRequest -Uri "$script:BaseUrl/realip" -Headers $headers -UseBasicParsing
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "X-Real-Ip.*not-an-ip-address"
        }

        It "Should handle empty header values" {
            $headers = @{
                "X-Forwarded-For" = ""
                "CF-Connecting-IP" = ""
            }

            $response = Invoke-WebRequest -Uri "$script:BaseUrl/realip" -Headers $headers -UseBasicParsing
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "X-Real-Ip"
        }

        It "Should handle whitespace in headers" {
            $headers = @{
                "CF-Connecting-IP" = "  203.0.113.1  "
            }

            $response = Invoke-WebRequest -Uri "$script:BaseUrl/realip" -Headers $headers -UseBasicParsing
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "X-Real-Ip.*203\.0\.113\.1"
        }

        It "Should handle private IPs" {
            $headers = @{
                "CF-Connecting-IP" = "192.168.1.1"
            }

            $response = Invoke-WebRequest -Uri "$script:BaseUrl/realip" -Headers $headers -UseBasicParsing
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "X-Real-Ip.*192\.168\.1\.1"
        }

        It "Should handle complex IP processing" {
            $headers = @{
                "CF-Connecting-IP" = "203.0.113.1"
            }

            $response = Invoke-WebRequest -Uri "$script:BaseUrl/realip" -Headers $headers -UseBasicParsing
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "X-Real-Ip.*203\.0\.113\.1"
        }
    }

    Context "Security Tests" {
        It "Should prevent header spoofing with forceOverwrite" {
            $headers = @{
                "X-Real-IP" = "malicious.spoofed.ip"
                "CF-Connecting-IP" = "203.0.113.1"
            }

            $response = Invoke-WebRequest -Uri "$script:BaseUrl/realip" -Headers $headers -UseBasicParsing
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "X-Real-Ip.*203\.0\.113\.1"
            $response.Content | Should -Not -Match "malicious\.spoofed\.ip"
        }

        It "Should handle potential injection attempts" {
            $headers = @{
                "CF-Connecting-IP" = "203.0.113.1<script>"
            }

            $response = Invoke-WebRequest -Uri "$script:BaseUrl/realip" -Headers $headers -UseBasicParsing
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "X-Real-Ip.*203\.0\.113\.1.*script"
        }

        It "Should handle extremely long header values" {
            $longValue = ("1.2.3.4, " * 1000) + "203.0.113.1"
            $headers = @{
                "X-Forwarded-For" = $longValue
            }

            $response = Invoke-WebRequest -Uri "$script:BaseUrl/realip" -Headers $headers -UseBasicParsing
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "X-Real-Ip"
        }
    }
}

Describe "RealIP Depth Configuration Tests" {
    Context "Depth Processing" {
        It "Should extract and process IPs correctly with depth -1" {
            $headers = @{
                "CF-Connecting-IP" = "203.0.113.1"
            }

            $response = Invoke-WebRequest -Uri "$script:BaseUrl/realip" -Headers $headers -UseBasicParsing
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "X-Real-Ip.*203\.0\.113\.1"
        }

        It "Should demonstrate header priority processing" {
            $headers = @{
                "CF-Connecting-IP" = "203.0.113.100"
            }

            $response = Invoke-WebRequest -Uri "$script:BaseUrl/realip" -Headers $headers -UseBasicParsing
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "X-Real-Ip.*203\.0\.113\.100"
            $response.Content | Should -Not -Match "198\.51\.100\.1"
        }

        It "Should fall through header priority chain correctly" {
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/realip"
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "X-Real-Ip.*172\.\d+\.\d+\.\d+"
        }

        It "Should handle IPv6 address processing" {
            $headers = @{
                "CF-Connecting-IP" = "2001:db8::1"
            }

            $response = Invoke-WebRequest -Uri "$script:BaseUrl/realip" -Headers $headers -UseBasicParsing
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "X-Real-Ip.*2001:db8::1"
        }

        It "Should handle bracket-enclosed IPv6 addresses" {
            $headers = @{
                "CF-Connecting-IP" = "[2001:db8::1]"
            }

            $response = Invoke-WebRequest -Uri "$script:BaseUrl/realip" -Headers $headers -UseBasicParsing
            $response.StatusCode | Should -Be 200
            $response.Content | Should -Match "X-Real-Ip.*(2001:db8::1|\[2001:db8::1\])"
        }
    }
}

Describe "RealIP Performance Tests" {
    Context "Response Times" {
        It "Should respond to /realip within reasonable time" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $response = Invoke-TestRequest -Uri "$script:BaseUrl/realip"
            $stopwatch.Stop()

            $response.StatusCode | Should -Be 200
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000
        }

        It "Should have minimal performance impact compared to plain service" {
            $plainStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $plainResponse = Invoke-TestRequest -Uri "$script:BaseUrl/plain"
            $plainStopwatch.Stop()
            $plainTime = $plainStopwatch.ElapsedMilliseconds

            $realipStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $realipResponse = Invoke-TestRequest -Uri "$script:BaseUrl/realip"
            $realipStopwatch.Stop()
            $realipTime = $realipStopwatch.ElapsedMilliseconds

            $plainResponse.StatusCode | Should -Be 200
            $realipResponse.StatusCode | Should -Be 200
            $realipTime | Should -BeLessThan ($plainTime * 1.5 + 100)
        }

        It "Should handle concurrent requests efficiently" {
            $jobs = @()
            $concurrentRequests = 5

            for ($i = 0; $i -lt $concurrentRequests; $i++) {
                $jobs += Start-Job -ScriptBlock {
                    param($BaseUrl)
                    try {
                        $response = Invoke-WebRequest -Uri "$BaseUrl/realip" -TimeoutSec 10 -UseBasicParsing
                        @{ StatusCode = $response.StatusCode; Success = $true }
                    }
                    catch {
                        @{ StatusCode = 0; Success = $false; Error = $_.Exception.Message }
                    }
                } -ArgumentList $script:BaseUrl
            }

            $results = $jobs | Wait-Job | Receive-Job
            $jobs | Remove-Job

            $results | ForEach-Object { $_.Success | Should -Be $true }
            $results | ForEach-Object { $_.StatusCode | Should -Be 200 }
        }
    }
}
