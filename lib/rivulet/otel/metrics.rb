module Rivulet
  module OTel
    class Metrics
      def initialize
        meter = OpenTelemetry.meter_provider.meter('rivulet')

        @request_count = meter.create_counter(
          'rivulet.request.count',
          unit: '1',
          description: 'Total number of requests'
        )

        @request_duration = meter.create_histogram(
          'rivulet.request.duration_ms',
          unit: 'ms',
          description: 'Request duration in milliseconds'
        )

        @db_queries = meter.create_counter(
          'rivulet.db.queries',
          unit: '1',
          description: 'Total number of database queries'
        )

        @db_duration = meter.create_histogram(
          'rivulet.db.duration_ms',
          unit: 'ms',
          description: 'Database query duration in milliseconds'
        )

        @step_duration = meter.create_histogram(
          'rivulet.step.duration_ms',
          unit: 'ms',
          description: 'Operation/step duration in milliseconds'
        )
      end

      def record_request(total_ms)
        @request_count.add(1)
        @request_duration.record(total_ms)
      end

      def record_db(elapsed_ms)
        @db_queries.add(1)
        @db_duration.record(elapsed_ms)
      end

      def record_step(name, duration_ms)
        @step_duration.record(duration_ms, attributes: { 'step.name' => name })
      end
    end
  end
end
