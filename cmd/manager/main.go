package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"log/slog"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"

	"gopkg.in/yaml.v3"

	"winetap/internal/manager"
)

func main() {
	configPath := flag.String("config", defaultConfigPath(), "path to YAML config file")
	flag.Parse()

	cfg, err := loadConfig(*configPath)
	if err != nil {
		log.Fatalf("config: %v", err)
	}

	logger, logHandler := manager.SetupLogger(cfg.LogLevel, cfg.LogFormat)
	slog.SetDefault(logger)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sig
		logger.Info("shutdown signal received")
		cancel()
	}()

	m, err := manager.New(cfg, *configPath, logger, logHandler)
	if err != nil {
		log.Fatalf("init manager: %v", err)
	}
	defer m.Close()

	m.Run(ctx)
}

func defaultConfigPath() string {
	dir, err := os.UserConfigDir()
	if err != nil {
		return "/etc/winetap/manager.yaml"
	}
	return filepath.Join(dir, "winetap", "manager.yaml")
}

func loadConfig(path string) (manager.Config, error) {
	cfg := manager.Config{
		LogLevel:  "info",
		LogFormat: "text",
	}
	f, err := os.Open(path)
	if os.IsNotExist(err) {
		return cfg, nil
	}
	if err != nil {
		return cfg, fmt.Errorf("open %s: %w", path, err)
	}
	defer f.Close()
	if err := yaml.NewDecoder(f).Decode(&cfg); err != nil {
		return cfg, fmt.Errorf("parse %s: %w", path, err)
	}
	return cfg, nil
}

