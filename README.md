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
- **Traefik**: 3.5.3

## Embedded Plugins

| Plugin | Default Key | Repository | Version |
|--------|-------------|------------|---------|
| **ModSecurity** | `modsecurity` | [david-garcia-garcia/traefik-modsecurity](https://github.com/david-garcia-garcia/traefik-modsecurity) | `v1.7.0` |
| **RealIP** | `realip` | [david-garcia-garcia/traefik-realip](https://github.com/david-garcia-garcia/traefik-realip) | `v1.0.0-beta.3` |
| **Geoblock** | `geoblock` | [david-garcia-garcia/traefik-geoblock](https://github.com/david-garcia-garcia/traefik-geoblock) | `v1.1.2-beta.0` |
| **CrowdSec** | `crowdsec` | [maxlerebourg/crowdsec-bouncer-traefik-plugin](https://github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin) | `v1.4.5` |
| **Sablier** | `sablier` | [sablierapp/sablier](https://github.com/sablierapp/sablier) | `v1.10.1` |

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

The project includes comprehensive test coverage:

### 1. Pester Integration Tests (API & Functionality)

Tests API endpoints, routing, middleware functionality, and performance:

```powershell
.\Test-Integration.ps1
```

**Coverage**: 59 tests covering:
- API endpoints (raw data, routers, services, middlewares)
- Service routing and middleware application
- Plugin functionality (RealIP header processing, etc.)
- Edge cases and security scenarios
- Performance and concurrent request handling

### 2. Cypress Dashboard UI Tests

Tests the Traefik WebUI dashboard to ensure proper embedding and visibility:

```bash
npm install
npm run test:dashboard
```

**Coverage**: 10 tests covering:
- Dashboard loads without errors
- All embedded plugins visible in UI
- Navigation to middlewares, routers, services tabs
- No "unknown plugin type" errors displayed
- Middleware details accessible
- No HTTP/template errors

**Why both?** The Pester tests validate functionality, but Cypress catches UI-specific issues like:
- Missing static files (WebUI not embedded)
- Dashboard showing "unknown plugin type" for embedded plugins
- Template parsing errors
- JavaScript loading issues

## How It Works

### Version Management

All versions are centralized in `versions.json`:
- Traefik version
- Plugin versions (used for both compilation and runtime assets)

This ensures consistency across the build, documentation, and releases.

**To update versions**: Edit `versions.json` and the Dockerfile will use those versions for:
- Docker build process (plugin compilation)
- Runtime assets (geoblock databases, crowdsec HTML templates)
- GitHub release notes
- Documentation

### Architecture

Instead of using Traefik's Yaegi interpreter to load plugins at runtime, we:

1. **Clone Traefik source** (version from `versions.json`)
2. **Add plugin dependencies** to `go.mod` using versions from `versions.json`
3. **Patch the plugin builder** with a minimal 15-line patch that checks for embedded plugins first
4. **Build WebUI** using npm (embedded via `go:embed` into the binary)
5. **Compile Traefik** with plugins natively compiled into the binary
6. **Copy runtime assets** (geoblock databases, crowdsec HTML templates) to final image

### Key Files

- `traefik/embedded-plugins/embedded-registry.go` - Plugin registry with CreateConfig() + mapstructure (Yaegi-compatible approach)
- `traefik/embedded-plugins/builder.patch` - Minimal patch to Traefik's plugin builder (only 5 lines added!)
- `traefik/Dockerfile` - Multi-stage build process

### Benefits Over Yaegi

- ✅ **No interpreter overhead** - Direct function calls instead of reflection
- ✅ **Compile-time type checking** - Catch errors during build, not runtime
- ✅ **Faster startup** - No plugin downloading or compilation
- ✅ **Same configuration** - Uses CreateConfig() + mapstructure like Yaegi
- ✅ **Zero config knowledge** - Registry is generic, no plugin-specific logic
