module Reports
  module Middleware
    class StatusCheck < Faraday::Middleware
      VALID_STATUS_CODES = [200, 302, 401, 403, 404, 422]

      def initialize(app)
        super(app)
      end

      def call(env)
        @app.call(env).on_complete do |response_env|
          unless VALID_STATUS_CODES.include? response_env.status
            raise RequestFailure, JSON.parse(response_env.body)["message"]
          end
        end
      end
    end
  end
end