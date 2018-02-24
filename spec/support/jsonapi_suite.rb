RSpec.configure do |config|
  config.include JsonapiSpecHelpers, type: :request
  config.extend ControllerMacros, type: :request
  config.include Devise::Test::ControllerHelpers, type: :request
end
