require "cinch/plugins/http_server"
require "rack/throttle"

module PugBot
  class WebPlugin
    include Cinch::Plugin
    extend Cinch::Plugins::HttpServer::Verbs

    get "/api/queue_list" do
      content_type :json
      bot.pug_plugin.queue_list.to_json
    end
  end
end

module Cinch
  module Plugins
    class HttpServer
      class CinchHttpServer
        use Rack::Throttle::Interval, min: 2
        use Rack::Throttle::Minute,   max: 30
      end
    end
  end
end
