# Traefik with Embedded Plugins

[Traefik](https://traefik.io/) image with **natively compiled** plugins for maximum performance.

## Why Embedded Plugins?

**Performance**: Plugins are compiled directly into the Traefik binary instead of being interpreted via Yaegi at runtime, resulting in:
- 🚀 **Faster startup** - No plugin downloading or compilation
- ⚡ **Better performance** - Native code execution (no interpreter overhead)
- 🔒 **More reliable** - No dependency on external plugin repositories
- 📦 **Smaller footprint** - Single binary with everything included

## Quick Start

Build and run locally:

```powershell
docker-compose up -d --build
```

Or use pre-built images from Docker Hub:

[davidbcn86/traefik-with-plugins](https://hub.docker.com/repository/docker/davidbcn86/traefik-with-plugins/general)

# Current container state

## Traefik Version
- **Traefik**: 3.1.7

## Embedded Plugins

| Plugin | Repository | Version/Branch |
|--------|------------|----------------|
| **ModSecurity** | [david-garcia-garcia/traefik-modsecurity](https://github.com/david-garcia-garcia/traefik-modsecurity) | `v1.7.0` |
| **Geoblock** | [david-garcia-garcia/traefik-geoblock](https://github.com/david-garcia-garcia/traefik-geoblock) | `v1.1.0-beta.2` |
| **Sablier** | [sablierapp/sablier](https://github.com/sablierapp/sablier) | `v1.8.1` |
| **CrowdSec Bouncer** | [maxlerebourg/crowdsec-bouncer-traefik-plugin](https://github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin) | `reportmetrics.2` |

## Configuration

The plugins are configured in `traefik.yml` as:

```yaml
experimental:
  localPlugins:
    modsecurity:
      moduleName: "github.com/david-garcia-garcia/traefik-modsecurity"
    geoblock:
      moduleName: "github.com/david-garcia-garcia/traefik-geoblock"
    sablier:
      moduleName: "github.com/sablierapp/sablier"
    bouncer:
      moduleName: "github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin"
```

## Supporting Services

The `compose.yaml` file includes additional services required for proper plugin operation:

| Service | Purpose | Plugin |
|---------|---------|--------|
| **waf** | OWASP ModSecurity CRS WAF service | ModSecurity |
| **crowdsec** | CrowdSec security engine | CrowdSec Bouncer |
| **dummy** | Backend service for WAF | ModSecurity |

## Test Routes

The integration tests verify the following routes:

| Route | Service | Middleware | Description |
|-------|---------|------------|-------------|
| `/plain` | whoami-plain | None | Basic service without middleware |
| `/modsecurity` | whoami-modsecurity | ModSecurity | Protected by WAF |
| `/geoblock` | whoami-geoblock | Geoblock | IP-based geo-blocking |
| `/crowdsec` | whoami-crowdsec | CrowdSec Bouncer | CrowdSec protection |

## Testing

The project includes Pester integration tests that can be run with:

```powershell
.\Test-Integration.ps1
```
