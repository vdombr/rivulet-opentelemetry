# frozen_string_literal: true

require 'dry/cli'
require 'tmpdir'
require 'fileutils'
require 'yaml'

require_relative '../../../../lib/rivulet/otel/cli'

RSpec.describe Rivulet::OTel::CLI::Commands::Setup do
  let(:app_name) { 'blog' }

  around do |example|
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        orig_stdout = $stdout
        $stdout = StringIO.new

        FileUtils.mkdir_p('config')
        File.write('config.ru', <<~RUBY)
          require 'rivulet'

          run Rivulet.app.startup
        RUBY
        File.write('config/application.rb', <<~RUBY)
          Rivulet.configure do |config|
            config.app.name     = app_name
            config.database.dsn = ENV.fetch('DATABASE_URL', 'postgres://localhost/db')

            config.logger.level = :info
          end
        RUBY
        File.write('docker-compose.yml', <<~YAML)
          services:
            app:
              build: .
              ports:
                - "9292:9292"
              volumes:
                - ./:/app
              depends_on:
                db:
                  condition: service_healthy
            db:
              image: postgres:17-alpine
          volumes:
            db:
        YAML

        begin
          example.run
        ensure
          $stdout = orig_stdout
        end
      end
    end
  end

  describe 'validation' do
    it 'fails when config.ru is missing' do
      FileUtils.rm('config.ru')
      expect { described_class.new.call }.to raise_error(SystemExit)
    end

    it 'fails when config/application.rb is missing' do
      FileUtils.rm('config/application.rb')
      expect { described_class.new.call }.to raise_error(SystemExit)
    end
  end

  describe 'file generation' do
    before { described_class.new.call }

    it 'generates the opentelemetry initializer' do
      expect(File.exist?('config/initializers/opentelemetry.rb')).to be(true)
      content = File.read('config/initializers/opentelemetry.rb')
      expect(content).to include("require 'rivulet/opentelemetry'")
      expect(content).to include("Rivulet::OTel.configure(service_name: Rivulet.config.app.name)")
    end
  end

  describe 'config/application.rb patching' do
    it 'adds the telemetry sink line' do
      described_class.new.call
      content = File.read('config/application.rb')
      expect(content).to include('config.telemetry.sink = Rivulet::OTel::Sink.new')
    end

    it 'adds the logger engine line' do
      described_class.new.call
      content = File.read('config/application.rb')
      expect(content).to include('config.logger.engine = Rivulet::OTel::Logger.new')
    end

    it 'is idempotent' do
      described_class.new.call
      first = File.read('config/application.rb')
      described_class.new.call
      second = File.read('config/application.rb')
      expect(first).to eq(second)
    end
  end

  describe 'docker-compose.yml patching' do
    it 'adds OTEL_EXPORTER_OTLP_ENDPOINT to app environment' do
      described_class.new.call
      compose = YAML.safe_load(File.read('docker-compose.yml'), permitted_classes: [Symbol])
      expect(compose.dig('services', 'app', 'environment')).to include('OTEL_EXPORTER_OTLP_ENDPOINT')
    end

    it 'adds lgtm to app depends_on' do
      described_class.new.call
      compose = YAML.safe_load(File.read('docker-compose.yml'), permitted_classes: [Symbol])
      expect(compose.dig('services', 'app', 'depends_on')).to have_key('lgtm')
    end

    it 'adds the lgtm service with grafana/otel-lgtm image' do
      described_class.new.call
      compose = YAML.safe_load(File.read('docker-compose.yml'), permitted_classes: [Symbol])
      expect(compose.dig('services', 'lgtm', 'image')).to eq('grafana/otel-lgtm:latest')
    end

    it 'preserves existing services' do
      described_class.new.call
      compose = YAML.safe_load(File.read('docker-compose.yml'), permitted_classes: [Symbol])
      expect(compose.dig('services', 'db')).not_to be_nil
    end

    it 'is idempotent' do
      described_class.new.call
      first = File.read('docker-compose.yml')
      described_class.new.call
      second = File.read('docker-compose.yml')
      expect(first).to eq(second)
    end
  end
end
