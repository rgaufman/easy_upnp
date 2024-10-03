# frozen_string_literal: true

module EasyUpnp
  class ArgumentValidator
    class Builder
      def initialize(&block)
        @validators = {}
        block&.call(self)
      end

      def in_range(min, max, step = 1)
        add_validator(RangeValidator.new((min..max).step(step)))
      end

      def allowed_values(*values)
        add_validator(AllowedValueValidator.new(*values))
      end

      def type(type)
        add_validator(TypeValidator.new(type))
      end

      def add_validator(validator)
        @validators[validator.class] = validator
      end

      def build
        ArgumentValidator.new(@validators)
      end
    end

    class RangeValidator
      attr_reader :range

      def initialize(range)
        @range = range
      end

      def validate(value)
        return if @range.include?(value)

        raise ArgumentError, "#{value} is not in allowed range of values: #{@range.inspect}"
      end
    end

    class AllowedValueValidator
      attr_reader :allowed_values

      def initialize(*allowed_values)
        @allowed_values = allowed_values
      end

      def validate(value)
        return if @allowed_values.include?(value)

        raise ArgumentError, "#{value} is not in list of allowed values: #{@allowed_values.inspect}"
      end
    end

    class TypeValidator
      # Valid UPnP types for each ruby class
      RUBY_TYPE_TO_UPNP_TYPE = {
        Array: %w[list],
        Float: %w[r4 r8 number fixed.14.4 float],
        Integer: %w[ui1 ui2 ui4 i1 i2 i4 int],
        String: %w[char string bin.base64 bin.hex uri uuid],
        TrueClass: %w[bool boolean],
        FalseClass: %w[bool boolean],
        DateTime: %w[date dateTime dateTime.tz time time.tz],
        Time: %w[date dateTime dateTime.tz time time.tz],
        Date: %w[date dateTime time]
      }.freeze

      # Inversion of RUBY_TYPE_TO_UPNP_TYPE.
      UPNP_TYPE_VALID_CLASSES = RUBY_TYPE_TO_UPNP_TYPE.map do |k, v|
        k = Kernel.const_get(k)
        v.map { |x| [x, k] }
      end.each_with_object({}) do |i, a|
        i.to_h.each do |x, y|
          a[x] ||= []
          a[x] << y
        end
      end.to_h

      attr_reader :valid_classes

      def initialize(type)
        @valid_classes = UPNP_TYPE_VALID_CLASSES[type]
        raise ArgumentError, "Unrecognized UPnP type: #{type}" if @valid_classes.nil?
      end

      def validate(value)
        return unless @valid_classes.none? { |x| value.is_a?(x) }

        raise ArgumentError, "#{value} is the wrong type. Should be one of: #{@valid_classes.inspect}"
      end
    end

    def initialize(validators)
      @validators = validators
    end

    def validate(value)
      @validators.each_value { |v| v.validate(value) }
      true
    end

    def required_class
      return nil unless @validators[TypeValidator]

      c = @validators[TypeValidator].valid_classes
      c.size == 1 ? c.first : c
    end

    def allowed_values
      return nil unless @validators[AllowedValueValidator]

      @validators[AllowedValueValidator].allowed_values
    end

    def valid_range
      return nil unless @validators[RangeValidator]

      @validators[RangeValidator].range
    end

    def self.build(&)
      Builder.new(&).build
    end

    def self.no_op
      build
    end

    def self.from_xml(xml)
      build do |v|
        v.type(xml.xpath('dataType').text)

        if (range = xml.xpath('allowedValueRange')).any?
          min = range.xpath('minimum').text
          max = range.xpath('maximum').text
          step = range.xpath('step')
          step = step.any? ? step.text : 1

          v.in_range(min.to_i, max.to_i, step.to_i)
        end

        if (list = xml.xpath('allowedValueList')).any?
          allowed_values = list.xpath('allowedValue').map(&:text)
          v.allowed_values(*allowed_values)
        end
      end
    end
  end
end
