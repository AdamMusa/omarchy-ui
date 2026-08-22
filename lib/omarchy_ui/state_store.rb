# frozen_string_literal: true

module OmarchyUI
  class StateStore
    def initialize(on_change)
      @values = {}
      @on_change = on_change
    end

    def define(name, initial)
      key = name.to_sym
      raise ArgumentError, "state already defined: #{key}" if @values.key?(key)

      @values[key] = initial
    end

    def [](name)
      @values.fetch(name.to_sym)
    end

    def []=(name, value)
      write(name.to_sym, value)
    end

    def method_missing(name, *arguments)
      raw = name.to_s
      if raw.end_with?("=")
        raise ArgumentError, "expected one value" unless arguments.length == 1

        return write(raw.delete_suffix("=").to_sym, arguments.first)
      end
      return @values.fetch(name) if arguments.empty? && @values.key?(name)

      super
    end

    def respond_to_missing?(name, include_private = false)
      key = name.to_s.delete_suffix("=").to_sym
      @values.key?(key) || super
    end

    private

    def write(key, value)
      raise NoMethodError, "unknown state: #{key}" unless @values.key?(key)
      return value if @values[key] == value

      previous = @values[key]
      @values[key] = value
      @on_change.call(key, previous, value)
      value
    end
  end
end
