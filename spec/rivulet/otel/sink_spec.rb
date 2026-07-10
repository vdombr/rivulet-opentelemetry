# frozen_string_literal: true

require_relative '../../spec_helper'

RSpec.describe Rivulet::OTel::Sink do
  let(:tracer) { OpenTelemetry.tracer_provider.tracer('test') }
  let(:metrics) { instance_double(Rivulet::OTel::Metrics) }
  let(:sink) do
    allow(Rivulet::OTel::Metrics).to receive(:new).and_return(metrics)
    allow(metrics).to receive(:record_request)
    allow(metrics).to receive(:record_db)
    allow(metrics).to receive(:record_step)
    described_class.new(tracer: tracer)
  end

  class FakeNode
    attr_reader :name, :duration_ms, :self_ms, :children

    def initialize(name, duration_ms: 10.0, self_ms: 5.0, children: [])
      @name = name
      @duration_ms = duration_ms
      @self_ms = self_ms
      @children = children
    end
  end

  describe '#on_start' do
    it 'creates a span with the node name' do
      node = FakeNode.new('TestOperation')
      sink.on_start(node, nil)

      span = Fiber[described_class::SPAN_STACK_KEY].last[:span]
      expect(span).not_to be_nil
    end

    it 'pushes span and context token onto fiber-local stack' do
      node = FakeNode.new('TestOperation')
      sink.on_start(node, nil)

      stack = Fiber[described_class::SPAN_STACK_KEY]
      expect(stack).to be_an(Array)
      expect(stack.size).to eq(1)
      expect(stack.first).to have_key(:span)
      expect(stack.first).to have_key(:token)
    end

    it 'nests child spans under the parent' do
      parent = FakeNode.new('Parent')
      child = FakeNode.new('Child')

      sink.on_start(parent, nil)
      sink.on_start(child, parent)

      stack = Fiber[described_class::SPAN_STACK_KEY]
      expect(stack.size).to eq(2)
    end
  end

  describe '#on_stop' do
    it 'ends the span and detaches context' do
      node = FakeNode.new('TestOperation')
      sink.on_start(node, nil)
      sink.on_stop(node)

      stack = Fiber[described_class::SPAN_STACK_KEY]
      expect(stack).to be_empty
    end

    it 'sets duration attributes on the span' do
      node = FakeNode.new('TestOperation', duration_ms: 42.5, self_ms: 30.0)
      sink.on_start(node, nil)
      sink.on_stop(node)
    end

    it 'records step metrics' do
      node = FakeNode.new('TestOperation', duration_ms: 42.5)
      sink.on_start(node, nil)
      sink.on_stop(node)

      expect(metrics).to have_received(:record_step).with('TestOperation', 42.5)
    end
  end

  describe '#on_db' do
    it 'adds a db.query event to the current span' do
      node = FakeNode.new('TestOperation')
      sink.on_start(node, nil)
      sink.on_db(12.3)

      sink.on_stop(node)
    end

    it 'records db metrics' do
      node = FakeNode.new('TestOperation')
      sink.on_start(node, nil)
      sink.on_db(12.3)

      expect(metrics).to have_received(:record_db).with(12.3)
    end

    it 'is a no-op when no span is active' do
      expect { sink.on_db(12.3) }.not_to raise_error
    end
  end

  describe '#on_root' do
    it 'records request metrics' do
      node = FakeNode.new('Root')
      sink.on_root(node, 100.0)

      expect(metrics).to have_received(:record_request).with(100.0)
    end
  end
end
