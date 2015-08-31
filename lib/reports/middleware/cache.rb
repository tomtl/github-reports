module Reports
  module Middleware
    class Cache < Faraday::Middleware
      def initialize(app)
        super(app)
        @app = app
        @storage = {}
      end

      def call(env)
        key = env.url.to_s
        cached_response = @storage[key]

        if cached_response
          if fresh?(cached_response)
            return cached_response unless needs_revalidation?(cached_response)
          else
            env.request_headers["If-None-Match"] = cached_response.headers['ETag']
          end
        end

        response = @app.call(env)
        response.on_complete do |response_env|
          if cachable_response?(response_env)
            if response.status == 304
              cached_response = @storage[key]
              cached_response.headers["Date"] = response.headers["Date"]
              @storage_key = cached_response

              response.env.update(cached_response.env)
            else
              @storage[key] = response
            end
          end
        end
        response
      end

      private

      def cachable_response?(env)
        env.method == :get &&
          env.response_headers['Cache-Control'] &&
            !env.response_headers['Cache-Control'].include?('no-store')
      end

      def needs_revalidation?(cached_response)
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