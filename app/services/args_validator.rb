class ArgsValidator
  def self.validate(args)
    new(args).validate
  end

  def initialize(args)
    @params = args[:params]
    @required = Array.wrap(args[:required]) || []
    @required_alternatives = Array.wrap(args[:required_alternatives]) || []
    @exclusive = Array.wrap(args[:exclusive]) || []
    @klass = args[:class]
    raise ArgumentError, 'no arguments provided for validation' unless params
  end

  def validate
    validate_hash
    validate_required_params
    validate_required_alternatives
    validate_exclusive_params
  end

  private

  attr_reader :params, :required, :required_alternatives, :exclusive, :klass

  def validate_hash
    raise ArgumentError, "arguments #{for_klass}must be provided as a hash" unless params.is_a?(Hash)
  end

  def validate_required_params
    required.each do |required_arg|
      raise ArgumentError, "arguments #{for_klass}must include #{required_arg}" unless params[required_arg]
    end
  end

  def validate_required_alternatives
    if required_alternatives.present?
      raise ArgumentError, "arguments #{for_klass}must include one of #{required_alternatives.to_sentence(two_words_connector: ' or ', last_word_connector: ', or ')}" unless
          required_alternatives.any? { |arg| params[arg] }
    end
  end

  def validate_exclusive_params
    if exclusive.present?
      params.each do |arg, _|
        raise ArgumentError, "arguments #{for_klass}may not include #{arg}" unless exclusive.include?(arg)
      end
    end
  end

  def for_klass
    klass && "for #{klass} "
  end
end