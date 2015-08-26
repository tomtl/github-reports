module Reports
  module Middleware
    class Cache < Faraday::Middleware
      def initialize(app)
        super(app)
        @storage = {}
      end

      def call(env)
        key = env.url.to_s
        return @storage[key] if @storage[key]

        response = @app.call(env)
        response.on_complete do
          @storage[key] = response if env.method == :get
        end
        response
      end
    end
  end
end