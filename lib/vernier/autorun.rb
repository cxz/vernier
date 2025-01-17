require "tempfile"
require "vernier"

module Vernier
  module Autorun
    class << self
      attr_accessor :collector
      attr_reader :options
    end
    @collector = nil

    @options = ENV.to_h.select { |k,v| k.start_with?("VERNIER_") }
    @options.transform_keys! do |key|
      key.sub(/\AVERNIER_/, "").downcase.to_sym
    end
    @options.freeze

    def self.start
      interval = options.fetch(:interval, 500).to_i

      STDERR.puts("starting profiler with interval #{interval}")

      @collector = Vernier::Collector.new(:wall, interval:)
      @collector.start
    end

    def self.stop
      result = @collector.stop
      @collector = nil
      output_path = options[:output]
      output_path ||= Tempfile.create(["profile", ".vernier.json"]).path
      File.write(output_path, Vernier::Output::Firefox.new(result).output)

      STDERR.puts(result.inspect)
      STDERR.puts("written to #{output_path}")
    end

    def self.running?
      !!@collector
    end

    def self.at_exit
      stop if running?
    end

    def self.toggle
      running? ? stop : start
    end
  end
end

unless Vernier::Autorun.options[:start_paused]
  Vernier::Autorun.start
end

if signal = Vernier::Autorun.options[:signal]
  STDERR.puts "to toggle profiler: kill -#{signal} #{Process.pid}"
  trap(signal) do
    Vernier::Autorun.toggle
  end
end

at_exit do
  Vernier::Autorun.at_exit
end
