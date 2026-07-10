require 'dry/cli'
require_relative 'cli/setup'

module Rivulet
  module OTel
    module CLI
      module Commands
        extend Dry::CLI::Registry

        register 'setup', Commands::Setup
      end
    end
  end
end
