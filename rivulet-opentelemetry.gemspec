require_relative 'lib/rivulet/opentelemetry/version'

Gem::Specification.new do |spec|
  spec.name    = 'rivulet-opentelemetry'
  spec.version = Rivulet::OTel::VERSION
  spec.summary = 'OpenTelemetry integration for Rivulet framework'
  spec.authors = ['Vladimir Dombrovskiy <vold@fastmail.com>']

  spec.files         = Dir['lib/**/*.rb'] + Dir['bin/*']
  spec.executables   = ['rivulet-otel']
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.2'

  spec.add_dependency 'rivulet-rb'
  spec.add_dependency 'opentelemetry-sdk'
  spec.add_dependency 'opentelemetry-exporter-otlp'
  spec.add_dependency 'opentelemetry-instrumentation-rack'
  spec.add_dependency 'opentelemetry-logs-sdk'
  spec.add_dependency 'opentelemetry-exporter-otlp-logs'
  spec.add_dependency 'opentelemetry-metrics-sdk'
  spec.add_dependency 'opentelemetry-exporter-otlp-metrics'
  spec.add_dependency 'dry-cli'

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
end
