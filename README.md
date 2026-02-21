# Traefik with Embedded Plugins

[Traefik](https://traefik.io/) image with plugins compiled into the binary (no Yaegi at runtime). 

> **⚠️ You should not run middlewares as Yaegi plugins in production.**
>
> Traefik’s default plugin system runs plugins via [Yaegi](https://github.com/traefik/yaegi) (a Go interpreter) at runtime. Middlewares run on every request, so they sit on the hot path. Using an interpreter for that workload has concrete drawbacks related to memory management, CPU usage and observability (see [feat: improve pprof experience by adding wrappers to interpreted functions by david-garcia-garcia · Pull Request #1712 · traefik/yaegi](https://github.com/traefik/yaegi/pull/1712))
>
> For production deployments where middlewares handle substantial traffic, use a Traefik build that **compiles those middlewares into the binary** instead of loading them as Yaegi plugins such as in [david-garcia-garcia/traefik-with-plugins: Traefik container with preloaded plugins in it](https://github.com/david-garcia-garcia/traefik-with-plugins) 
> 
> **For more details and discussion, read [Traefik issue #12213](https://github.com/traefik/traefik/issues/12213) in the Traefik issue queue.**

## Why This Project Exists and what it does

This repository builds Traefik with a fixed set of middlewares compiled directly into the binary (no Yaegi for those plugins).  The built Traefik instance still supports Yeagi plugins if needed.

To accomplish this the upstream source code is patched consistently, see details of patches in:

[traefik-with-plugins/traefik/embedded-plugins at main · david-garcia-garcia/traefik-with-plugins](https://github.com/david-garcia-garcia/traefik-with-plugins/tree/main/traefik/embedded-plugins)

## Tests

To ensure stability this project includes end to end testing of the resulting Traefik image that makes sure the middlewares and traefik itself are working:

* Cypress test coverage [david-garcia-garcia/traefik-with-plugins: Traefik container with preloaded plugins in it](https://github.com/david-garcia-garcia/traefik-with-plugins)
* e2e test: [traefik-with-plugins/scripts at main · david-garcia-garcia/traefik-with-plugins](https://github.com/david-garcia-garcia/traefik-with-plugins/tree/main/scripts)

## Why Embedded Plugins?

Plugins are compiled into the Traefik binary instead of being loaded and interpreted by Yaegi:

- No plugin download or Yaegi compilation at startup.
- Native execution: no interpreter overhead on each request.
- No dependency on external plugin stores at runtime.
- Single binary; no separate plugin artifacts.
- Improved resource usage and observability

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

See the [releases](https://github.com/david-garcia-garcia/traefik-with-plugins/releases) section for details on what versions of the plugins and traefik are used.

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
