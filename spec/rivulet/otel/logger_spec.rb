# frozen_string_literal: true

require_relative '../../spec_helper'

RSpec.describe Rivulet::OTel::Logger do
  describe '#info' do
    it 'writes to stdout' do
      logger = described_class.new(level: :debug)
      expect { logger.info('test message') }.to output(/test message/).to_stdout
    end
  end

  describe '#debug' do
    it 'writes to stdout when level is debug' do
      logger = described_class.new(level: :debug)
      expect { logger.debug('debug message') }.to output(/debug message/).to_stdout
    end

    it 'does not write to stdout when level is info' do
      logger = described_class.new(level: :info)
      expect { logger.debug('debug message') }.not_to output.to_stdout
    end
  end

  describe '#warn' do
    it 'writes to stdout' do
      logger = described_class.new(level: :warn)
      expect { logger.warn('warn message') }.to output(/warn message/).to_stdout
    end
  end

  describe '#error' do
    it 'writes to stdout' do
      logger = described_class.new(level: :error)
      expect { logger.error('error message') }.to output(/error message/).to_stdout
    end
  end

  describe '#fatal' do
    it 'writes to stdout' do
      logger = described_class.new(level: :fatal)
      expect { logger.fatal('fatal message') }.to output(/fatal message/).to_stdout
    end
  end

  describe 'level filtering' do
    it 'respects the configured level' do
      logger = described_class.new(level: :warn)
      expect { logger.debug('should not appear') }.not_to output.to_stdout
      expect { logger.info('should not appear') }.not_to output.to_stdout
      expect { logger.warn('should appear') }.to output(/should appear/).to_stdout
      expect { logger.error('should appear') }.to output(/should appear/).to_stdout
    end
  end

  describe 'block support' do
    it 'evaluates block when no message is given' do
      logger = described_class.new(level: :debug)
      expect { logger.info { 'block message' } }.to output(/block message/).to_stdout
    end
  end

  describe 'empty message handling' do
    it 'does not output empty messages' do
      logger = described_class.new(level: :debug)
      expect { logger.info('') }.not_to output.to_stdout
    end
  end
end
