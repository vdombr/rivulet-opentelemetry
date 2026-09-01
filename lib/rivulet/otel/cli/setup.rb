require 'fileutils'
require 'yaml'

module Rivulet
  module OTel
    module CLI
      module Commands
        class Setup < Dry::CLI::Command
          desc "Wire OpenTelemetry into an existing Rivulet app"

          def call(**)
            validate_app!

            generate_files
            patch_application_config
            patch_docker_compose

            puts "\nDone! Next steps:"
            puts "  docker compose up --build"
            puts "  Open Grafana at http://localhost:3000 (admin/admin)"
          end

          private

          def validate_app!
            unless File.exist?('config.ru') && File.read('config.ru').include?("require 'rivulet'")
              puts "Error: not a Rivulet application (config.ru not found or missing 'require \"rivulet\"')"
              exit 1
            end

            unless File.exist?('config/application.rb')
              puts "Error: config/application.rb not found"
              exit 1
            end
          end

          def generate_files
            FileUtils.mkdir_p('config/initializers')

            write 'config/initializers/opentelemetry.rb', opentelemetry_initializer
          end

          def write(path, content)
            File.write(path, content)
            puts "  create  #{path}"
          end

          def patch_application_config
            path = 'config/application.rb'
            content = File.read(path)
            changed = false

            unless content.include?('config.telemetry.sink = Rivulet::OTel::Sink.new')
              content = content.sub(/(end\s*\n?\z)/, "  config.telemetry.sink = Rivulet::OTel::Sink.new\n\\1")
              changed = true
            end

            unless content.include?('config.logger.engine = Rivulet::OTel::Logger.new')
              content = content.sub(/(end\s*\n?\z)/, "  config.logger.engine = Rivulet::OTel::Logger.new\n\\1")
              changed = true
            end

            if changed
              File.write(path, content)
              puts "  patch   #{path}"
            else
              puts "  skip    #{path} (already patched)"
            end
          end

          def patch_docker_compose
            path = 'docker-compose.yml'
            return puts "  skip    #{path} (not found)" unless File.exist?(path)

            compose = YAML.safe_load(File.read(path), permitted_classes: [Symbol])
            return puts "  skip    #{path} (already patched)" if compose.dig('services', 'lgtm')

            app_env = compose.dig('services', 'app', 'environment')
            if app_env.is_a?(Hash)
              app_env['OTEL_EXPORTER_OTLP_ENDPOINT'] = 'http://lgtm:4318'
            elsif app_env.is_a?(Array)
              app_env << 'OTEL_EXPORTER_OTLP_ENDPOINT=http://lgtm:4318'
            else
              compose['services']['app']['environment'] = { 'OTEL_EXPORTER_OTLP_ENDPOINT' => 'http://lgtm:4318' }
            end

            app_depends = compose.dig('services', 'app', 'depends_on')
            if app_depends.is_a?(Hash)
              app_depends['lgtm'] = { 'condition' => 'service_started' }
            elsif app_depends.is_a?(Array)
              app_depends << 'lgtm'
            else
              compose['services']['app']['depends_on'] = { 'lgtm' => { 'condition' => 'service_started' } }
            end

            compose['services']['lgtm'] = lgtm_service

            File.write(path, YAML.dump(compose, line_width: -1))
            puts "  patch   #{path}"
          end

          def lgtm_service
            {
              'image' => 'grafana/otel-lgtm:latest',
              'ports' => ['3000:3000', '4318:4318']
            }
          end

          def opentelemetry_initializer
            <<~RUBY
              require 'rivulet/opentelemetry'

              Rivulet::OTel.configure(service_name: Rivulet.config.app.name)
            RUBY
          end
        end
      end
    end
  end
end
