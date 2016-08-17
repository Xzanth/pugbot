require "dm-core"
require "dm-types"

module PugBot
  module Storage
    # Model of User to be stored in database, either authed with an authname or
    # not authed with just a nick.
    class User
      include DataMapper::Resource

      property :id,     Serial
      property :authed, Boolean
      property :auth,   String
      property :nick,   String

      has n, :gameplays
      has n, :games, through: :gameplays
    end

    # Model to facilitate many to many mapping of users to game, also include
    # the hostmask the user played with as this could change game to game.
    class Gameplay
      include DataMapper::Resource

      property :id,   Serial
      property :host, String, length: 255

      belongs_to :user, key: true
      belongs_to :game, key: true
    end

    # Model of Game to be stored in database, string describing queue name and
    # the start and end times.
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
