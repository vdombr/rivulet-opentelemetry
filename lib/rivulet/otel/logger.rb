module Rivulet
  module OTel
    class Logger
      SEVERITY_MAP = {
        debug: { text: 'DEBUG', number: 5 },
        info:  { text: 'INFO',  number: 9 },
        warn:  { text: 'WARN',  number: 13 },
        error: { text: 'ERROR', number: 17 },
        fatal: { text: 'FATAL', number: 21 },
      }.freeze

      LEVELS = { debug: 0, info: 1, warn: 2, error: 3, fatal: 4 }.freeze

      def initialize(level: :info)
        @level = LEVELS.fetch(level, 1)
      end

      def debug(message = nil, &block)
        log(:debug, message, &block)
      end

      def info(message = nil, &block)
        log(:info, message, &block)
      end

      def warn(message = nil, &block)
        log(:warn, message, &block)
      end

      def error(message = nil, &block)
        log(:error, message, &block)
      end

      def fatal(message = nil, &block)
        log(:fatal, message, &block)
      end

      private

      def log(severity, message = nil, &block)
        return if LEVELS.fetch(severity, 1) < @level

        body = (message || (block && block.call)).to_s
        return if body.empty?

        write_stdout(severity, body)
        emit_otel(severity, body)
      end

      def write_stdout(severity, body)
        ts = Time.now.strftime('%Y-%m-%d %H:%M:%S %z')
        $stdout.puts("[#{severity.to_s.upcase}] #{ts} #{body}")
      end

      def emit_otel(severity, body)
        otel_logger = OpenTelemetry.instance_variable_get(:@logger_provider)&.logger(name: 'rivulet')
        return unless otel_logger

        sev = SEVERITY_MAP.fetch(severity, SEVERITY_MAP[:info])
        otel_logger.on_emit(
          body: body,
          severity_text: sev[:text],
          severity_number: sev[:number]
        )
      end
    end
  end
end
