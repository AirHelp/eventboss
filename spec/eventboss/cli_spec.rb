require 'spec_helper'
require 'eventboss/cli'

RSpec.describe Eventboss::CLI do
  subject { Eventboss::CLI.instance }

  before do
    stub_const 'Eventboss::Configuration', Class.new
    stub_const 'Eventboss::Configuration::OPTS_ALLOWED_IN_CONFIG_FILE', %i[concurrency listeners]

    subject.options = described_class::DEFAULT_OPTIONS.dup
  end

  describe '#parse' do
    describe 'require' do
      it 'accepts with -r' do
        subject.parse(%w[eventboss -r ./spec/eventboss/fixtures/fake_env.rb])

        expect(subject.options[:require]).to eq './spec/eventboss/fixtures/fake_env.rb'
      end
    end

    describe 'config file' do
      context 'with supported options' do
        it 'accepts with -C' do
          subject.parse(%w[eventboss -C ./spec/eventboss/fixtures/config.yml])

          expect(subject.options[:config]).to eq './spec/eventboss/fixtures/config.yml'
          expect(Eventboss.configuration.listeners).to eq(include: ['Listener1'], exclude: ['Listener2'])
          expect(Eventboss.configuration.concurrency).to eq 5
        end
      end

      context 'with not supported option' do
        before do
          stub_const 'Eventboss::Configuration::OPTS_ALLOWED_IN_CONFIG_FILE', %i[listeners]
        end

        it 'exits with status 1' do
          expect {
            expect(Eventboss.logger).to receive(:error).with("Not supported option (concurrency) provided in config file.")
            subject.parse(%w[eventboss -C ./spec/eventboss/fixtures/config.yml])
          }.to raise_error SystemExit
        end
      end
    end

    describe 'default config file' do
      describe 'when required path is a directory' do
        it 'tries config/eventboss.yml from required directory' do
          subject.parse(%w[eventboss -r ./spec/eventboss/fixtures])

          expect(subject.options[:config]).to eq './spec/eventboss/fixtures/config/eventboss.yml'
          expect(Eventboss.configuration.concurrency).to eq 10
        end
      end

      describe 'when required path is a file' do
        it 'tries config/eventboss.yml from current diretory' do
          described_class::DEFAULT_OPTIONS[:require] = './spec/eventboss/fixtures' # stub current dir – ./

          subject.parse(%w[eventboss -r ./spec/eventboss/fixtures/fake_env.rb])

          expect(subject.options[:config]).to eq './spec/eventboss/fixtures/config/eventboss.yml'
          expect(Eventboss.configuration.concurrency).to eq 10
        end
      end

      describe 'without any required path' do
        it 'tries config/eventboss.yml from current diretory' do
          described_class::DEFAULT_OPTIONS[:require] = './spec/eventboss/fixtures' # stub current dir – ./

          subject.parse(%w[eventboss])

          expect(subject.options[:config]).to eq './spec/eventboss/fixtures/config/eventboss.yml'
          expect(Eventboss.configuration.concurrency).to eq 10
        end
      end
    end
  end

  describe '#run' do
    describe 'when path is existing file' do
      before do
        subject.options[:require] = './spec/eventboss/fixtures/fake_env.rb'
      end

      it 'requires application' do
        expect(Eventboss).to receive(:launch)
        subject.run

        expect($LOADED_FEATURES).to include /eventboss\/fixtures\/fake_env/
      end
    end

    describe 'when path is non existing file' do
      before do
        subject.options[:require] = './spec/eventboss/fixtures/non_existing_file.rb'
      end

      it 'raises LoadError' do
        expect { subject.run }.to raise_error LoadError
      end
    end
  end
end
