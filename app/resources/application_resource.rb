class ApplicationResource < JsonapiCompliable::Resource
  use_adapter JsonapiCompliable::Adapters::ActiveRecord

  # The filter[:editable] param is handled in the controller using Pundit policy scopes.
  # This allow_filter exists only to avoid raising an error when filter[:editable]
  # is used.

  allow_filter :editable do |scope|
    scope
  end
end
