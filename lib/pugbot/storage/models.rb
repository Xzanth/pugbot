require "dm-core"
require "dm-types"

module PugBot
  module Storage
    class User
      include DataMapper::Resource

      property :id,     Serial
      property :authed, Boolean
      property :auth,   String

      has n, :gameplays
      has n, :games, through: :gameplays
    end

    class Gameplay
      include DataMapper::Resource

      property :id,   Serial
      property :ip,   IPAddress

      belongs_to :user, key: true
      belongs_to :game, key: true
    end

    class Game
      include DataMapper::Resource

      property :id,       Serial
      property :queue,    String
      property :started,  DateTime
      property :finished, DateTime

      has n, :gameplays
      has n, :users, through: :gameplays
    end
  end
end
