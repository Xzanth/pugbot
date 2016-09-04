require "sinatra/base"

module PugBot
  class Web < Sinatra::Base
    get "/api/" do
      content_type :json
      settings.plugin.queue_list.to_json
    end
  end
end
