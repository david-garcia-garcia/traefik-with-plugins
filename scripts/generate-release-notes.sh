#!/bin/bash
# Generate release notes with versions, repositories and Docker Hub link

set -e

VERSIONS_FILE="${1:-.env}"
DOCKER_TAG="${2}"

if [ ! -f "$VERSIONS_FILE" ]; then
    echo "Error: $VERSIONS_FILE not found"
    exit 1
fi

# Source the env file
source "$VERSIONS_FILE"

# Generate release notes
cat << EOF
## Docker Image

📦 **Docker Hub**: https://hub.docker.com/repository/docker/davidbcn86/traefik-with-plugins/tags${DOCKER_TAG:+/$DOCKER_TAG}

## Components

### Traefik Core
- **Version**: ${TRAEFIK_VERSION}
- **Repository**: https://${TRAEFIK_REPO}

### Embedded Plugins

- **ModSecurity**
  - Version: ${PLUGIN_MODSECURITY_VERSION}
  - Repository: https://${PLUGIN_MODSECURITY_REPO}

- **RealIP**
  - Version: ${PLUGIN_REALIP_VERSION}
  - Repository: https://${PLUGIN_REALIP_REPO}

- **Geoblock**
  - Version: ${PLUGIN_GEOBLOCK_VERSION}
  - Repository: https://${PLUGIN_GEOBLOCK_REPO}

- **CrowdSec Bouncer**
  - Version: ${PLUGIN_CROWDSEC_VERSION}
  - Repository: https://${PLUGIN_CROWDSEC_REPO}

- **Sablier**
  - Version: ${PLUGIN_SABLIER_VERSION}
  - Repository: https://${PLUGIN_SABLIER_REPO}

---

All plugins are natively compiled into the Traefik binary for maximum performance and compatibility.
EOF
