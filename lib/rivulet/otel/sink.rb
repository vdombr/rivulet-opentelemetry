require 'opentelemetry'

module Rivulet
  module OTel
    class Sink
      SPAN_STACK_KEY = :rivulet_otel_span_stack

      def initialize(tracer: nil)
        @tracer = tracer || OpenTelemetry.tracer_provider.tracer('rivulet')
        @metrics = begin
          Rivulet::OTel::Metrics.new
        rescue
          nil
        end
      end

      def on_start(node, parent)
        span = @tracer.start_span(node.name, kind: :internal)
        span.set_attribute('rivulet.node.name', node.name)

        ctx = OpenTelemetry::Trace.context_with_span(span)
        token = OpenTelemetry::Context.attach(ctx)

        stack = Fiber[SPAN_STACK_KEY] ||= []
        stack.push(span: span, token: token)
      end

      def on_stop(node)
        entry = (Fiber[SPAN_STACK_KEY] ||= []).pop
        return unless entry

        span = entry[:span]
        token = entry[:token]

        span.set_attribute('rivulet.duration_ms', node.duration_ms)
        span.set_attribute('rivulet.self_ms', node.self_ms)

        @metrics&.record_step(node.name, node.duration_ms)

        span.finish
        OpenTelemetry::Context.detach(token)
      end

      def on_db(elapsed_ms)
        span = current_span
        return unless span

        span.add_event('db.query', attributes: { 'db.elapsed_ms' => elapsed_ms })
        @metrics&.record_db(elapsed_ms)
      end

      def on_root(node, total_ms)
        @metrics&.record_request(total_ms)
      end

      private

      def current_span
        stack = Fiber[SPAN_STACK_KEY]
        return OpenTelemetry::Trace::Span.new unless stack&.any?

        stack.last[:span]
      end
    end
  end
end
