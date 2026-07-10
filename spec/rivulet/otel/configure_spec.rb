# frozen_string_literal: true

require_relative '../../spec_helper'

RSpec.describe Rivulet::OTel do
  describe '.configure' do
    context 'when OTEL_EXPORTER_OTLP_ENDPOINT is not set' do
      it 'does not configure the SDK' do
        original = ENV.delete('OTEL_EXPORTER_OTLP_ENDPOINT')
        expect { described_class.configure(service_name: 'test') }.not_to raise_error
        ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = original if original
      end
    end

    context 'when OTEL_EXPORTER_OTLP_ENDPOINT is set' do
      it 'configures the SDK without errors' do
        ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://localhost:4318'
        expect { described_class.configure(service_name: 'test') }.not_to raise_error
        ENV.delete('OTEL_EXPORTER_OTLP_ENDPOINT')
      end

      it 'sets OTEL_METRICS_EXPORTER to none' do
        ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://localhost:4318'
        described_class.configure(service_name: 'test')
        expect(ENV['OTEL_METRICS_EXPORTER']).to eq('none')
        ENV.delete('OTEL_EXPORTER_OTLP_ENDPOINT')
      end
    end
  end
end
