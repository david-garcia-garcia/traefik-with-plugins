# Integration Tests

This directory contains Pester integration tests for the Traefik with Plugins setup.

## Test files

Pester discovers `*.Tests.ps1` in this directory. Shared helpers live in `TestHelpers.ps1`.

| File | Domain |
|---|---|
| `traefik.Tests.ps1` | API, dashboard, 404, container health |
| `plain.Tests.ps1` | `/plain` (no middleware) |
| `modsecurity.Tests.ps1` | `/modsecurity` |
| `geoblock.Tests.ps1` | `/geoblock` |
| `crowdsec.Tests.ps1` | `/crowdsec` (upstream) |
| `crowdsecfork.Tests.ps1` | `/crowdsecfork` (compiled) |
| `realip.Tests.ps1` | `/realip` |

`./Test-Integration.ps1` runs the whole directory. To run one domain:

```powershell
Invoke-Pester -Path ./scripts/geoblock.Tests.ps1 -Output Detailed
```

## Running the Tests

The tests are designed to be run via the main `Test-Integration.ps1` script in the project root:

```powershell
# Run all integration tests
./Test-Integration.ps1

# Run tests but leave Docker services running for debugging
./Test-Integration.ps1 -SkipDockerCleanup

# Run tests assuming services are already running
./Test-Integration.ps1 -SkipWait

# Benchmark compiled vs Yaegi stacks (compose.yaml + compose.bench.yaml)
./Test-Benchmark.ps1
./Test-Benchmark.ps1 -Requests 500 -Concurrency 16
```

## Compiled vs Yaegi benchmark

The test stack is `compose.yaml` + `traefik.yml` (CI / `./Test-Integration.ps1`). The bench is an overlay:

```powershell
docker compose --env-file versions.conf -f compose.yaml -f compose.bench.yaml up -d
./Test-Benchmark.ps1
```

`../Test-Benchmark.ps1` applies that overlay itself. It measures four stacks, each with compiled (embedded) middlewares and Yaegi (`traefik.bench.yml` `experimental.localPlugins`) middlewares:

| Stack | Compiled | Yaegi |
|---|---|---|
| none | `/plain` | `/plain` (same) |
| geo | `/bench/geo` | `/bench/geo-yaegi` |
| geo+crowdsec | `/bench/geo-crowdsec` | `/bench/geo-crowdsec-yaegi` |
| geo+crowdsec+modsec (apache) | `/bench/geo-crowdsec-modsec` | `/bench/geo-crowdsec-modsec-yaegi` |
| geo+crowdsec+modsec (nginx) | `/bench/geo-crowdsec-modsec-nginx` | `/bench/geo-crowdsec-modsec-nginx-yaegi` |

CrowdSec stream cursors do not collide (distinct LAPI keys):

- compiled: `lapi-key-bench-compiled`
- Yaegi: `lapi-key-bench-yaegi`

## Test Configuration

The tests use the following endpoints:
- **Main Application**: `http://localhost:8000`
- **Traefik API**: `http://localhost:8080`

## Notes

- Tests include retry logic for improved reliability
- Tests are designed to be simple and focused on basic functionality
- Tests can be expanded as needed for additional plugin-specific functionality 