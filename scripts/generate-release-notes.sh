#!/bin/bash
# Generate simple release notes with versions only

set -e

VERSIONS_FILE="${1:-.env}"

if [ ! -f "$VERSIONS_FILE" ]; then
    echo "Error: $VERSIONS_FILE not found"
    exit 1
fi

# Source the env file
source "$VERSIONS_FILE"

# Generate simple release notes
cat << EOF
## Versions

**Traefik**: ${TRAEFIK_VERSION}

### Embedded Plugins

- **ModSecurity**: ${PLUGIN_MODSECURITY_VERSION}
- **RealIP**: ${PLUGIN_REALIP_VERSION}
- **Geoblock**: ${PLUGIN_GEOBLOCK_VERSION}
- **CrowdSec**: ${PLUGIN_CROWDSEC_VERSION}
- **Sablier**: ${PLUGIN_SABLIER_VERSION}

---

All plugins are natively compiled into the Traefik binary for maximum performance.
EOF
