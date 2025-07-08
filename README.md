# Traefik Image (with plugins)

[Traefik](https://traefik.io/) image with embeded plugins. 

You need to add plugins to your traefik images because:

* You don't want your Traefik pods not to start when Traefik's plugin repository is down
* Traefik pods start much faster if they don't have to pull the plugins every time they start

See:

* [Embedding plugins beforehand to avoid on-startup compiling - Traefik / Traefik v2 - Traefik Labs Community Forum](https://community.traefik.io/t/embedding-plugins-beforehand-to-avoid-on-startup-compiling/16816/4)
* [traefik/plugindemo: This repository includes an example plugin, for you to use as a reference for developing your own plugins](https://github.com/traefik/plugindemo#local-mode)

To build the image locally use:

```powershell
.\build -StartContainers
```

The project includes a sample traefik.yml

Built images are available at:

[davidbcn86/traefik-with-plugins general | Docker Hub](https://hub.docker.com/repository/docker/davidbcn86/traefik-with-plugins/general)

# Current container state

## Traefik Version
- **Traefik**: 3.1.7

## Embedded Plugins

| Plugin | Repository | Version/Branch |
|--------|------------|----------------|
| **ModSecurity** | [madebymode/traefik-modsecurity-plugin](https://github.com/madebymode/traefik-modsecurity-plugin) | `backoff` |
| **Geoblock** | [david-garcia-garcia/traefik-geoblock](https://github.com/david-garcia-garcia/traefik-geoblock) | `v1.1.0-beta.2` |
| **Sablier** | [sablierapp/sablier](https://github.com/sablierapp/sablier) | `v1.8.1` |
| **CrowdSec Bouncer** | [maxlerebourg/crowdsec-bouncer-traefik-plugin](https://github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin) | `reportmetrics.2` |

## Configuration

The plugins are configured in `traefik.yml` as:

```yaml
experimental:
  localPlugins:
    modsecurity:
      moduleName: "github.com/madebymode/traefik-modsecurity-plugin"
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
