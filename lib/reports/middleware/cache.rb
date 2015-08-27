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
          cache_control_header = response_env.response_headers["Cache-Control"]
          if cache_control_header && allows_storage?(cache_control_header)
            @storage[key] = response
          end
        end

        response
      end

      private

      def allows_storage?(cache_control_header)
        !cache_control_header.include?("no-store")
      end

      def useable_cache?(cached_response)
        !mandatory_refresh?(cached_response) && fresh?(cached_response)
      end

      def mandatory_refresh?(cached_response)
        ["non-cache", "must-validate"].include?(
          cached_response.headers["Cache-Control"])
      end

      def fresh?(cached_response)
        age = response_age(cached_response)
        max_age = response_max_age(cached_response)

        if age && max_age
          age < max_age
        end
      end

      def response_age(cached_response)
        date = cached_response.headers["Date"]
        time = Time.httpdate(date) if date
        (Time.now - time).floor if time
      end

      def response_max_age(cached_response)
        cache_control = cached_response.headers["Cache-Control"]
        return nil unless cache_control
        match = cache_control.match(/max\-age=(\d+)/)
        match[1].to_i if match
      end
    end
  end
end