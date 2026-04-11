package manager

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// Config holds all manager settings persisted to the YAML config file.
type Config struct {
	Server       string `yaml:"server"`
	PhoneAddress string `yaml:"phone_address"` // cached from mDNS discovery; "http://host:port"
	LogLevel     string `yaml:"log_level"`
	LogFormat    string `yaml:"log_format"`
	QtStyle      string `yaml:"qt_style"`   // Qt widget style name (e.g. "Fusion"); empty = system default
	AIProvider   string `yaml:"ai_provider"` // "chatgpt" or "claude"; empty defaults to "chatgpt"
}

// saveConfig writes cfg to path, creating directories as needed.
func saveConfig(path string, cfg Config) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return fmt.Errorf("create config dir: %w", err)
	}
	f, err := os.Create(path)
	if err != nil {
		return fmt.Errorf("create file: %w", err)
	}
	defer f.Close()
	if err := yaml.NewEncoder(f).Encode(cfg); err != nil {
		return err
	}
	return f.Close()
}
