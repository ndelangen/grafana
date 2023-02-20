package updatechecker

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/hashicorp/go-version"
	"github.com/prometheus/client_golang/prometheus"
	"go.opentelemetry.io/otel/codes"

	"github.com/grafana/grafana/pkg/infra/log"
	"github.com/grafana/grafana/pkg/infra/tracing"
	"github.com/grafana/grafana/pkg/services/updatechecker/instrumentation"
	"github.com/grafana/grafana/pkg/setting"
)

// Create and register metrics into the default Prometheus registry

var grafanaUpdateCheckerMetrics = instrumentation.NewPrometheusMetrics("grafana_update_checker").
	WithMustRegister(prometheus.DefaultRegisterer)

type GrafanaService struct {
	hasUpdate     bool
	latestVersion string

	enabled        bool
	grafanaVersion string
	httpClient     httpClient
	mutex          sync.RWMutex
	log            log.Logger
	tracer         tracing.Tracer
}

func ProvideGrafanaService(cfg *setting.Cfg, tracer tracing.Tracer) *GrafanaService {
	return &GrafanaService{
		enabled:        cfg.CheckForGrafanaUpdates,
		grafanaVersion: cfg.BuildVersion,
		httpClient: instrumentation.NewInstrumentedHTTPClient(
			&http.Client{Timeout: time.Second * 10},
			tracer,
			instrumentation.WithMetrics(grafanaUpdateCheckerMetrics),
		),
		log:    log.New("grafana.update.checker"),
		tracer: tracer,
	}
}

func (s *GrafanaService) IsDisabled() bool {
	return !s.enabled
}

func (s *GrafanaService) Run(ctx context.Context) error {
	s.instrumentedCheckForUpdates(ctx)

	ticker := time.NewTicker(time.Minute * 10)
	run := true

	for run {
		select {
		case <-ticker.C:
			s.instrumentedCheckForUpdates(ctx)
		case <-ctx.Done():
			run = false
		}
	}

	return ctx.Err()
}

func (s *GrafanaService) instrumentedCheckForUpdates(ctx context.Context) {
	start := time.Now()
	ctx, span := s.tracer.Start(ctx, "updatechecker.GrafanaService.checkForUpdates")
	defer span.End()
	ctxLogger := s.log.FromContext(ctx)
	if err := s.checkForUpdates(ctx); err != nil {
		span.SetStatus(codes.Error, fmt.Sprintf("update check failed: %s", err))
		span.RecordError(err)
		ctxLogger.Error("Update check failed", "error", err, "duration", time.Since(start))
		return
	}
	ctxLogger.Info("Update check succeeded", "duration", time.Since(start))
}

func (s *GrafanaService) checkForUpdates(ctx context.Context) error {
	ctxLogger := s.log.FromContext(ctx)
	ctxLogger.Debug("Checking for updates")
	resp, err := s.httpClient.Get(ctx, "https://raw.githubusercontent.com/grafana/grafana/main/latest.json")
	if err != nil {
		return fmt.Errorf("failed to get latest.json repo from github.com: %w", err)
	}
	defer func() {
		if err := resp.Body.Close(); err != nil {
			ctxLogger.Warn("Failed to close response body", "err", err)
		}
	}()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("update check failed, reading response from github.com: %w", err)
	}

	type latestJSON struct {
		Stable  string `json:"stable"`
		Testing string `json:"testing"`
	}
	var latest latestJSON
	err = json.Unmarshal(body, &latest)
	if err != nil {
		return fmt.Errorf("failed to unmarshal latest.json: %w", err)
	}

	s.mutex.Lock()
	defer s.mutex.Unlock()
	if strings.Contains(s.grafanaVersion, "-") {
		s.latestVersion = latest.Testing
		s.hasUpdate = !strings.HasPrefix(s.grafanaVersion, latest.Testing)
	} else {
		s.latestVersion = latest.Stable
		s.hasUpdate = latest.Stable != s.grafanaVersion
	}

	currVersion, err1 := version.NewVersion(s.grafanaVersion)
	latestVersion, err2 := version.NewVersion(s.latestVersion)
	if err1 == nil && err2 == nil {
		s.hasUpdate = currVersion.LessThan(latestVersion)
	}

	return nil
}

func (s *GrafanaService) UpdateAvailable() bool {
	s.mutex.RLock()
	defer s.mutex.RUnlock()
	return s.hasUpdate
}

func (s *GrafanaService) LatestVersion() string {
	s.mutex.RLock()
	defer s.mutex.RUnlock()
	return s.latestVersion
}
