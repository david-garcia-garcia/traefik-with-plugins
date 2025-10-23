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

## Embedded Plugins

| Plugin | Default Key | Repository |
|--------|-------------|------------|
| **ModSecurity** | `modsecurity` | [david-garcia-garcia/traefik-modsecurity](https://github.com/david-garcia-garcia/traefik-modsecurity) |
| **RealIP** | `realip` | [david-garcia-garcia/traefik-realip](https://github.com/david-garcia-garcia/traefik-realip) |
| **Geoblock** | `geoblock` | [david-garcia-garcia/traefik-geoblock](https://github.com/david-garcia-garcia/traefik-geoblock) |
| **CrowdSec** | `crowdsec` | [maxlerebourg/crowdsec-bouncer-traefik-plugin](https://github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin) |
| **Sablier** | `sablier` | [sablierapp/sablier](https://github.com/sablierapp/sablier) |

## Configuration

### Basic Usage

Embedded plugins are used just like regular plugins in your Docker labels or static configuration:

```yaml
# Docker Compose labels example
labels:
  - "traefik.http.middlewares.my-waf.plugin.modsecurity.modSecurityUrl=http://waf:8080"
  - "traefik.http.middlewares.my-crowdsec.plugin.crowdsec.enabled=true"
  - "traefik.http.middlewares.my-geoblock.plugin.geoblock.defaultAllow=true"
  - "traefik.http.middlewares.my-realip.plugin.realip.enabled=true"
```

### Custom Plugin Keys (Environment Variable Remapping)

For backward compatibility or custom naming preferences, you can remap plugin keys using environment variables:

```yaml
# In your docker-compose.yaml or Kubernetes deployment
environment:
  # Use "bouncer" instead of "crowdsec" in your configurations
  - TRAEFIK_EMBEDDED_CROWDSEC_KEY=bouncer
  
  # Use "waf" instead of "modsecurity"
  - TRAEFIK_EMBEDDED_MODSECURITY_KEY=waf
  
  # Any plugin can be remapped
  - TRAEFIK_EMBEDDED_REALIP_KEY=real-ip
  - TRAEFIK_EMBEDDED_GEOBLOCK_KEY=geo
  - TRAEFIK_EMBEDDED_SABLIER_KEY=sablier-custom
```

**Format**: `TRAEFIK_EMBEDDED_{PLUGINNAME}_KEY={custom-key}`

This allows you to migrate from existing Yaegi-based configurations without changing your middleware definitions.

### Example with Remapping

```yaml
# With TRAEFIK_EMBEDDED_CROWDSEC_KEY=bouncer set
labels:
  # You can now use "bouncer" instead of "crowdsec"
  - "traefik.http.middlewares.my-bouncer.plugin.bouncer.enabled=true"
  - "traefik.http.middlewares.my-bouncer.plugin.bouncer.crowdsecLapiKey=xxx"
```

