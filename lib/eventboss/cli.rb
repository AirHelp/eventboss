require 'rubygems'
begin
  require 'dotenv'
  Dotenv.load
rescue LoadError
end
require 'optparse'
require 'yaml'
require 'erb'
require 'singleton'
require_relative '../eventboss'

module Eventboss
  class CLI
    include Singleton

    attr_accessor :options

    DEFAULT_OPTIONS = {
      require: '.'
    }

    def initialize
      self.options = DEFAULT_OPTIONS.dup
    end

    def parse(args = ARGV)
      parse_options(args)
      load_config_file
    end

    def run
      boot_system

      Eventboss.logger.info('Starting eventboss...')

      Eventboss.launch
    end

    private

    def boot_system
      require 'rails'
      if ::Rails::VERSION::MAJOR < 4
        require File.expand_path('config/environment.rb')
      else
        require File.expand_path('config/application.rb')
        require File.expand_path('config/environment.rb')
      end

      Eventboss.logger.debug('Loaded rails...')
      # Due to a changes introduced in Rails 6 regarding autoloading
      # we need to determine how to perform eager_load
      # @see https://weblog.rubyonrails.org/2019/2/22/zeitwerk-integration-in-rails-6-beta-2/
      if ::Rails.try(:autoloaders).try(:zeitwerk_enabled?)
        ::Zeitwerk::Loader.eager_load_all
      else
        ::Rails.application.eager_load!
      end
    rescue LoadError
      Eventboss.logger.debug('Seems like not a Rails app')

      if options[:require].nil?
        Eventboss.logger.warn('Please use -r to load a custom app entrypoint')
        exit(0)
      else
        Eventboss.logger.debug("Loading #{options[:require]}")
        require File.expand_path(options[:require])
      end
    end

    def parse_options(args)
      option_parser(options).parse!(args)

      options
    end

    def load_config_file
      # check config file presence
      if options[:config]
        raise ArgumentError, "No such file #{options[:config]}" unless File.exist?(options[:config])
      else
        config_dir = if File.directory?(options[:require].to_s)
                       File.join(options[:require], 'config')
                     else
                       File.join(DEFAULT_OPTIONS[:require], 'config')
                     end

        %w[eventboss.yml eventboss.yml.erb].each do |config_file|
          path = File.join(config_dir, config_file)
          options[:config] ||= path if File.exist?(path)
        end
      end

      # parse config file options
      if options[:config]
        opts = parse_config(options[:config])

        opts.each do |option_name, option|
          if Eventboss::Configuration::OPTS_ALLOWED_IN_CONFIG_FILE.include?(option_name)
            Eventboss.configuration.public_send("#{option_name}=", option)
          else
            Eventboss.logger.error("Not supported option (#{option_name}) provided in config file.")
            exit(1)
          end
        end
      end
    end

    def parse_config(path)
      opts = YAML.load(ERB.new(File.read(path)).result) || {}

      if opts.respond_to? :deep_symbolize_keys!
        opts.deep_symbolize_keys!
      else
        symbolize_keys_deep!(opts)
      end

      opts
    end

    def symbolize_keys_deep!(hash)
      hash.keys.each do |k|
        symkey = k.respond_to?(:to_sym) ? k.to_sym : k
        hash[symkey] = hash.delete k
        symbolize_keys_deep! hash[symkey] if hash[symkey].is_a? Hash
      end
    end

    def option_parser(opts)
      parser = OptionParser.new do |parser|
        parser.on('-r', '--require LIBRARY', 'Require custom app entrypoint') do |lib|
          opts[:require] = lib
        end

        parser.on('-C', '--config PATH', 'Config file path') do |config|
          opts[:config] = config
        end
      end

      parser.banner = "Eventboss [options]"
      parser.on_tail "-h", "--help", "Show help" do
        Eventboss.logger.info parser
        exit 1
      end

      parser
    end
  end
end
