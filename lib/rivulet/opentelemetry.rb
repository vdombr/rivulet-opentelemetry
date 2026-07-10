require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/rack'
require 'opentelemetry/sdk/logs'
require 'opentelemetry/exporter/otlp_logs'
require 'opentelemetry-metrics-sdk'
require 'opentelemetry/exporter/otlp_metrics'

require_relative 'opentelemetry/version'
require_relative 'otel/sink'
require_relative 'otel/logger'
require_relative 'otel/metrics'

module Rivulet
  module OTel
    class << self
      def configure(service_name: 'rivulet')
        return unless ENV['OTEL_EXPORTER_OTLP_ENDPOINT']

        ENV['OTEL_METRICS_EXPORTER'] ||= 'none'

        OpenTelemetry::SDK.configure do |c|
          c.service_name = service_name
          c.use 'OpenTelemetry::Instrumentation::Rack'
        end

        configure_logs(service_name)
        configure_metrics
      end

      private

      def configure_logs(service_name)
        logger_provider = OpenTelemetry::SDK::Logs::LoggerProvider.new
        logger_provider.add_log_record_processor(
          OpenTelemetry::SDK::Logs::Export::SimpleLogRecordProcessor.new(
            OpenTelemetry::Exporter::OTLP::Logs::LogsExporter.new
          )
        )

        OpenTelemetry.instance_variable_set(:@logger_provider, logger_provider)
        logger_provider.logger(name: service_name)
      end

      def configure_metrics
        exporter = OpenTelemetry::Exporter::OTLP::Metrics::MetricsExporter.new
        OpenTelemetry.meter_provider.add_metric_reader(
          OpenTelemetry::SDK::Metrics::Export::PeriodicMetricReader.new(exporter: exporter)
        )
      end
    end
  end
end
