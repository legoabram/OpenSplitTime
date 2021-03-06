# TODO This is a temporary monkey patch until workers: 0 is added
# to a future version of Rails (likely 5.1.5)

require "rack/handler/puma"

module ActionDispatch
  module SystemTesting
    class Server # :nodoc:
      class << self
        attr_accessor :silence_puma
      end

      self.silence_puma = false

      def run
        register
        setup
      end

      private
      def register
        Capybara.register_server :rails_puma do |app, port, host|
          Rack::Handler::Puma.run(
              app,
              Port: port,
              Threads: "0:1",
              workers: 0,
              daemon: false,
              Silent: self.class.silence_puma
          )
        end
      end

      def setup
        set_server
        set_port
      end

      def set_server
        Capybara.server = :rails_puma
      end

      def set_port
        Capybara.always_include_port = true
      end
    end
  end
end
