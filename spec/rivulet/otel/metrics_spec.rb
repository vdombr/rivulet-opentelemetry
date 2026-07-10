# frozen_string_literal: true

require_relative '../../spec_helper'

RSpec.describe Rivulet::OTel::Metrics do
  let(:counter) { instance_double('OpenTelemetry::Metrics::Counter', add: nil) }
  let(:histogram) { instance_double('OpenTelemetry::Metrics::Histogram', record: nil) }
  let(:meter) do
    instance_double(
      'OpenTelemetry::Metrics::Meter',
      create_counter: counter,
      create_histogram: histogram
    )
  end
  let(:meter_provider) do
    instance_double('OpenTelemetry::SDK::Metrics::MeterProvider', meter: meter)
  end

  before do
    allow(OpenTelemetry).to receive(:meter_provider).and_return(meter_provider)
  end

  describe '#initialize' do
    it 'creates all instruments' do
      described_class.new

      expect(meter).to have_received(:create_counter).with('rivulet.request.count', unit: '1', description: anything)
      expect(meter).to have_received(:create_counter).with('rivulet.db.queries', unit: '1', description: anything)
      expect(meter).to have_received(:create_histogram).with('rivulet.request.duration_ms', unit: 'ms', description: anything)
      expect(meter).to have_received(:create_histogram).with('rivulet.db.duration_ms', unit: 'ms', description: anything)
      expect(meter).to have_received(:create_histogram).with('rivulet.step.duration_ms', unit: 'ms', description: anything)
    end
  end

  describe '#record_request' do
    it 'increments the request counter and records duration' do
      metrics = described_class.new
      metrics.record_request(42.5)

      expect(counter).to have_received(:add).with(1)
      expect(histogram).to have_received(:record).with(42.5)
    end
  end

  describe '#record_db' do
    it 'increments the db counter and records duration' do
      metrics = described_class.new
      metrics.record_db(12.3)

      expect(counter).to have_received(:add).with(1)
      expect(histogram).to have_received(:record).with(12.3)
    end
  end

  describe '#record_step' do
    it 'records step duration with name attribute' do
      metrics = described_class.new
      metrics.record_step('Services::Users::Steps::LoadUser', 5.2)

      expect(histogram).to have_received(:record).with(
        5.2,
        attributes: { 'step.name' => 'Services::Users::Steps::LoadUser' }
      )
    end
  end
end
