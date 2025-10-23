package plugins

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"strings"

	"github.com/mitchellh/mapstructure"
	"github.com/rs/zerolog/log"

	// Import our embedded plugins
	geoblock "github.com/david-garcia-garcia/traefik-geoblock"
	modsecurity "github.com/david-garcia-garcia/traefik-modsecurity"
	realip "github.com/david-garcia-garcia/traefik-realip"
	bouncer "github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin"
	bouncerconfig "github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin/pkg/configuration"
	sablier "github.com/sablierapp/sablier/plugins/traefik"
)

// embeddedPluginDescriptor describes an embedded plugin with a generic approach
type embeddedPluginDescriptor struct {
	createConfig func() interface{}
	callNew      func(ctx context.Context, next http.Handler, config interface{}, name string) (http.Handler, error)
}

// basePluginRegistry is the internal registry with default plugin names
var basePluginRegistry = map[string]embeddedPluginDescriptor{
	"modsecurity": {
		createConfig: func() interface{} { return modsecurity.CreateConfig() },
		callNew: func(ctx context.Context, next http.Handler, config interface{}, name string) (http.Handler, error) {
			return modsecurity.New(ctx, next, config.(*modsecurity.Config), name)
		},
	},
	"realip": {
		createConfig: func() interface{} { return realip.CreateConfig() },
		callNew: func(ctx context.Context, next http.Handler, config interface{}, name string) (http.Handler, error) {
			return realip.New(ctx, next, config.(*realip.Config), name)
		},
	},
	"crowdsec": {
		createConfig: func() interface{} {
			// Check if bouncer has CreateConfig, otherwise use configuration.New()
			if cfg := bouncer.CreateConfig(); cfg != nil {
				return cfg
			}
			return bouncerconfig.New()
		},
		callNew: func(ctx context.Context, next http.Handler, config interface{}, name string) (http.Handler, error) {
			return bouncer.New(ctx, next, config.(*bouncerconfig.Config), name)
		},
	},
	"geoblock": {
		createConfig: func() interface{} { return geoblock.CreateConfig() },
		callNew: func(ctx context.Context, next http.Handler, config interface{}, name string) (http.Handler, error) {
			return geoblock.New(ctx, next, config.(*geoblock.Config), name)
		},
	},
	"sablier": {
		createConfig: func() interface{} { return sablier.CreateConfig() },
		callNew: func(ctx context.Context, next http.Handler, config interface{}, name string) (http.Handler, error) {
			return sablier.New(ctx, next, config.(*sablier.Config), name)
		},
	},
}

// EmbeddedPluginRegistry is the public registry that includes remapped plugin names
// Remapping is controlled via environment variables:
// - TRAEFIK_EMBEDDED_MODSECURITY_KEY="customname" -> allows plugin.customname instead of plugin.modsecurity
// - TRAEFIK_EMBEDDED_REALIP_KEY="customname" -> allows plugin.customname instead of plugin.realip
// - TRAEFIK_EMBEDDED_CROWDSEC_KEY="bouncer" -> allows plugin.bouncer instead of plugin.crowdsec
// - TRAEFIK_EMBEDDED_GEOBLOCK_KEY="customname" -> allows plugin.customname instead of plugin.geoblock
// - TRAEFIK_EMBEDDED_SABLIER_KEY="customname" -> allows plugin.customname instead of plugin.sablier
var EmbeddedPluginRegistry = buildPluginRegistry()

func buildPluginRegistry() map[string]embeddedPluginDescriptor {
	registry := make(map[string]embeddedPluginDescriptor)

	for defaultName, descriptor := range basePluginRegistry {
		// Build environment variable name from plugin name
		// e.g., "crowdsec" -> "TRAEFIK_EMBEDDED_CROWDSEC_KEY"
		envVarName := "TRAEFIK_EMBEDDED_" + strings.ToUpper(defaultName) + "_KEY"

		// Check if there's a custom name configured via environment variable
		if customName := strings.TrimSpace(os.Getenv(envVarName)); customName != "" {
			// Register with custom name
			registry[customName] = descriptor
			log.Info().
				Str("plugin", defaultName).
				Str("customKey", customName).
				Str("envVar", envVarName).
				Msg("Embedded plugin registered with custom key")
		} else {
			// Register with default name
			registry[defaultName] = descriptor
		}
	}

	return registry
}

// IsEmbeddedPlugin checks if a plugin name is in the embedded registry
func IsEmbeddedPlugin(pluginName string) bool {
	_, exists := EmbeddedPluginRegistry[pluginName]
	return exists
}

// BuildEmbeddedPlugin builds an embedded plugin middleware using the same approach as Yaegi
func BuildEmbeddedPlugin(ctx context.Context, pluginName string, config map[string]interface{}, middlewareName string) (Constructor, error) {
	descriptor, exists := EmbeddedPluginRegistry[pluginName]
	if !exists {
		return nil, fmt.Errorf("unknown embedded plugin: %s", pluginName)
	}

	log.Ctx(ctx).Debug().Str("plugin", pluginName).Str("middleware", middlewareName).Msg("Building embedded plugin")

	// Create config using CreateConfig() - same as Yaegi
	cfg := descriptor.createConfig()

	// Decode the config map into the struct using mapstructure - same as Yaegi
	if len(config) > 0 {
		decoderConfig := &mapstructure.DecoderConfig{
			DecodeHook:       mapstructure.StringToSliceHookFunc(","),
			WeaklyTypedInput: true,
			Result:           cfg,
		}

		decoder, err := mapstructure.NewDecoder(decoderConfig)
		if err != nil {
			return nil, fmt.Errorf("failed to create configuration decoder: %w", err)
		}

		if err := decoder.Decode(config); err != nil {
			return nil, fmt.Errorf("failed to decode configuration: %w", err)
		}
	}

	// Return a constructor that calls the plugin's New function directly (no reflection needed!)
	return func(ctx context.Context, next http.Handler) (http.Handler, error) {
		return descriptor.callNew(ctx, next, cfg, middlewareName)
	}, nil
}
