# frozen_string_literal: true

require "slack_keep_presence/version"
require "slack"
require "faye/websocket"
require "eventmachine"
require "logger"

module SlackKeepPresence
  class Main
    MAX_RETRIES = 5
    RETRY_DELAY = 2 # seconds
    attr_accessor :logger, :client, :user, :ws, :should_shutdown, :retry_count

    def initialize(options)
      @logger = Logger.new($stdout)
      @logger.level = options[:debug] ? Logger::DEBUG : Logger::INFO
      @client = Slack::Client.new(token: ENV["SLACK_TOKEN"])
      @retry_count = 0

      get_user
      keep_presence
    end

    def get_user
      auth_test_with_retry
      @user = @auth_test_result["user_id"]
      logger.info("Authenticated as #{user}")
    end

    def auth_test_with_retry
      begin
        @auth_test_result = client.auth_test
        raise "Authentication failed" unless @auth_test_result["ok"]
      rescue => e
        if @retry_count < MAX_RETRIES
          @retry_count += 1
          logger.error("Authentication failed: #{e.message}, retrying...")
          sleep RETRY_DELAY**@retry_count
          retry
        else
          logger.error("Authentication failed after multiple attempts, exiting")
          exit(1)
        end
      end
    end

    def clean_shutdown
      puts "Shutting down..."
      @should_shutdown = true
      ws.close if ws
      EM.stop
      exit
    end

    def keep_presence
      Signal.trap("INT")  { clean_shutdown }
      Signal.trap("TERM") { clean_shutdown }

      EM.run do
        start_realtime

        EM.add_periodic_timer(300) do
          set_presence_active
          next unless ws

          timeouter = EventMachine::Timer.new(2) do
            logger.info("Connection to Slack terminated, reconnecting...")
            restart_connection
          end

          ws.ping("detecting presence") do
            timeouter.cancel
          end
        end
      end
    end

    def start_realtime
      @should_shutdown = false
      @retry_count = 0

      begin
        rtm = client.post("rtm.connect", batch_presence_aware: true)
        ws_url = rtm["url"]

        @ws = Faye::WebSocket::Client.new(ws_url, nil, ping: 30)

        ws.on :open do |_event|
          logger.info("Connected to Slack RealTime API")

          payload = {
            type: "presence_sub",
            ids: [user]
          }

          ws.send(payload.to_json)

          res = client.users_getPresence(user: user)
          logger.debug res.to_s
        end

        ws.on :message do |event|
          data = JSON.parse(event.data)

          if data["type"] == "presence_change"
            logger.debug("Got event: #{event.data}")
            next unless data["user"] == user
            next unless data["presence"] == "away"

            away_info = client.users_getPresence(user: user)
            logger.debug(away_info)

            if away_info["manual_away"]
              logger.info("User marked as manual_away, skipping")
              next
            end

            logger.info("Presence changed to #{data['presence']}")
            logger.info("Marking #{user} as active")

            set_presence_active
            restart_connection
          end
        end

        ws.on [:close, :error] do |_event|
          next if should_shutdown

          logger.debug("Connection to Slack RealTime API terminated, reconnecting")
          sleep 5
          start_realtime
        end
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
        handle_reconnect_failure(e)
      end
    end

    def handle_reconnect_failure(exception)
      if @retry_count < MAX_RETRIES
        @retry_count += 1
        logger.error("Failed to connect (#{exception.message}), retrying in #{RETRY_DELAY**@retry_count} seconds...")
        sleep RETRY_DELAY**@retry_count
        start_realtime
      else
        logger.error("Failed to reconnect after multiple attempts, exiting")
        exit(1)
      end
    end

    def restart_connection
      @should_shutdown = true
      @ws&.close
      @ws = nil
      @retry_count = 0
      begin
        start_realtime
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
        handle_reconnect_failure(e)
      end
    end

    def set_presence_active
      res = client.users_getPresence(user: user)
      res["last_activity_time"] = Time.at(res["last_activity"])
      res["last_activity_minutes"] = (Time.now - res["last_activity_time"]) / 60

      logger.debug("Status before: #{res}")

      if res["manual_away"]
        logger.debug("User set manual away, not updating presence")
        return
      end

      set_res = client.users_setPresence(presence: "auto", set_active: true)
      if !set_res["ok"]
        logger.debug("Failed to set presence #{set_res}")
      end

      res = client.users_getPresence(user: user)
      logger.debug("Status after: #{res}")
    end
  end
end
