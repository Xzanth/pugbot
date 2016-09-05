require "sinatra/base"
require "rack/throttle"

module PugBot
  class Web < Sinatra::Base
    use Rack::Throttle::Interval, min: 2
    use Rack::Throttle::Minute,   max: 30

    get "/api/" do
      content_type :json
      settings.plugin.queue_list.to_json
    end
  end
end
