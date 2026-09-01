# rivulet-opentelemetry

OpenTelemetry integration for [Rivulet](https://github.com/vdombr/rivulet).

Provides per-operation and per-step tracing, log correlation, and request/DB
metrics via the single `grafana/otel-lgtm` image (OTel Collector, Tempo,
Loki, Prometheus, and Grafana in one container).

## Quick Start

### 1. Add the gem

```ruby
# Gemfile
gem 'rivulet-opentelemetry'
```

### 2. Install and run setup

```bash
docker compose up --build
docker compose exec app bundle exec rivulet-otel setup
docker compose up --build
```

The setup command:
- Generates `config/initializers/opentelemetry.rb`
- Patches `config/application.rb` to set `config.telemetry.sink` and `config.logger.engine`
- Adds a single `lgtm` service to `docker-compose.yml`

All patches are idempotent — running setup twice is safe.

### 3. View traces, logs, and metrics

Grafana is available at `http://localhost:3000` (admin/admin) with:
- **Tempo** — traces (per-operation and per-step spans)
- **Loki** — logs (correlated to traces via span context)
- **Prometheus** — metrics (request count/duration, DB queries/duration, step duration)

## What it captures

### Traces

One span per `Rivulet::Operation` and one per `Rivulet::Step`, with correct
parent-child nesting. Database queries are recorded as events on the current
span via the existing `Rivulet::Telemetry::SequelExtension`.

### Logs

A `Rivulet::OTel::Logger` replaces the default dry-logger. Each log record
is emitted as a real OTel log with the current span context attached
(trace_id, span_id), enabling trace-to-log correlation in Grafana. Logs are
also written to stdout for local visibility.

### Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `rivulet.request.count` | counter | Total number of requests |
| `rivulet.request.duration_ms` | histogram | Request duration |
| `rivulet.db.queries` | counter | Total database queries |
| `rivulet.db.duration_ms` | histogram | DB query duration |
| `rivulet.step.duration_ms` | histogram | Operation/step duration (tagged with `step.name`) |

## How it works

### Exporter gating

The OTel exporter activates only when `OTEL_EXPORTER_OTLP_ENDPOINT` is set.
Without it, the SDK and instrumentation are loaded but no data is exported.
The logger still writes to stdout.

### Architecture

The framework defines a pluggable sink protocol (`Rivulet::Telemetry::Sink`).
This gem provides `Rivulet::OTel::Sink` as an implementation that emits
OpenTelemetry spans, log records, and metrics.

## License

Apache 2.0
