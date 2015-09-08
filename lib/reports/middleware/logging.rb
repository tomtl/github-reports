require "logger"

module Reports
  module Middleware
    class Logging < Faraday::Middleware
      def initialize(app)
        super(app)
        @logger = Logger.new(STDOUT)
        @logger.formatter = proc do |severity, datetime, program, message|
          message + "\n"
        end
      end

      def call(env)
        start_time = Time.now

        @app.call(env).on_complete do |response_env|
          duration = Time.now - start_time
          url, method, status = env.url.to_s, env.method, response_env.status
          cached = response_env.response_headers["X-Faraday-Cache-Status"] ? "hit" : "miss" 
          @logger.debug "-> %s %s %d (%.3f s) %s" % [
            url, method.to_s.upcase, status, duration, cached]
        end
      end
    end
  end
end
