module Reports
  module Middleware
    class Cache < Faraday::Middleware
      def initialize(app)
        super(app)
        @storage = {}
      end

      def call(env)
        key = env.url.to_s
        cached_response = @storage[key]

        if cached_response && useable_cache?(cached_response)
          return cached_response
        end

        response = @app.call(env)
        response.on_complete do |response_env|
          @storage[key] = response if cachable_response?(response_env)
        end

        response
      end

      def useable_cache?(cached_response)
        cached_response &&
          !["must-validate", "no-cache", "no-store"].include?(
            cached_response.headers["Cache-Control"])
      end

      def cachable_response?(env)
        env.method == :get &&
          env.response_headers["Cache-Control"] &&
          !["no-store", "no-cache"].include?(
            env.response_headers["Cache-Control"])
      end
    end
  end
end