module PugBot
  # This class is an object for each queue for each gametype that contains the
  # players, the list of games related to that queue and all associated
  # features.
  class Queue
    # @return [String] The name of the queue
    attr_reader :name

    # @return [Array<Game>] All the games being played in this queue
    attr_reader :games

    # @return [QueueList] The list of all the queues
    attr_reader :queue_list

    # @return [Array<Cinch::User>] The list of all the users in the queue
    attr_reader :users

    # Create a new queue in a queue list, should never be called directly,
    # should always be called with QueueList.new_queue
    # @param [QueueList] queue_list The list of queues this is being created in
    # @param [String] name The name of this queue
    # @param [Integer] max The number of players required to start a game
    # @see QueueList.new_queue
    def initialize(queue_list, name, max)
      @name = name
      @max = max
      @users = []
      @wait = []
      @games = []
      @queue_list = queue_list
    end

    # Removed method join

    # Removed method leave

    # Test if a user is in this queue.
    # @param [Cinch::User] user The user to test for
    # @return [Boolean] Whether they are in the queue or not
    def listed?(user)
      @users.include?(user)
    end

    # Add a user to this queue and start tracking them.
    # @param [Cinch::User] user The user to add
    def add(user)
      @users.push(user)
      user.track = true
      ready
    end

    # Test if a user is in the wait queue.
    # @param [Cinch::User] user The user to test for
    # @return [Boolean] Whether they are in the wait queue or not
    def listed_wait?(user)
      @wait.include?(user)
    end

    # Test if a user is either in the queue or the wait queue
    # @param [Cinch::User] user The user to test for
    # @return [Boolean] Whether they are in either queue or not
    def listed_either?(user)
      listed_wait?(user) or listed?(user)
    end

    # Removed method ingame?

    # Add a user to the wait queue.
    # @param [Cinch::User] user The user to add
    def add_wait(user)
      @wait.push(user)
      user.track = true
    end

    # Remove a user from either normal or waiting queue and stop tracking
    # them if they are not doing anything else.
    # @param [Cinch::User] user The user to remove
    def remove(user)
      @users.delete(user)
      @wait.delete(user)
      user.track = false unless @queue_list.player_active?(user)
    end

    # Remove a game that has finished
    # @param [Game] game The game that can be removed
    def finish(game)
      @games.delete(game)
    end

    # Check if enough people are signed up to start a game and if they are
    # then start one, alerting the relevant channels.
    def ready
      if @users.length >= @max
        ingame = @users.take(@max)
        game = Game.new(self, ingame)
        @games.push(game)
        @users -= ingame
        ingame.each do |user|
          user.status = :ingame
          @queue_list.remove_from_queues(user)
        end
        text = "Game #{@name} - starting for #{ingame.join(' ')}"
        @queue_list.plugin.send(text)
      end
    end

    # Check the users waiting in @wait and see if any have become able to be
    # added, if they have randomize them into queue.
    def check_waiters
      finished = @wait.select { |user| user.status == :standby }
      unless finished.empty?
        finished.shuffle!
        @users += finished
        @wait -= finished
        @queue_list.plugin.send("Users have been randomized into queue")
        ready
        @queue_list.plugin.update_topic
      end
    end

    # Find a game in this queue when supplied with a string argument that is the
    # number game in the list. If there is only one game don't require an
    # argument but if there are more then return nil for no argument.
    # @param [String] arg A string consisting of the number of the game to find
    # @return [Game] The game found, or nil if the game is ambiguous
    def find_game_by_arg(arg)
      return @games.first if @games.length == 1
      return nil if arg.nil?
      @games[arg.to_i - 1]
    end

    # Just print the queue name, whether there is one in progress or not
    # (and the number if there are multiple) and the number of players and subs.
    # @return [String] The status of this queue
    def print_short
      ingame = @games.select { |game| game.status == :ingame }
      text = "#{@name} - "
      if ingame.length == 1
        text << "IN GAME - "
      elsif ingame.length > 1
        text << "#{@games.length} GAMES - "
      end
      text << "[#{@users.length}/#{@max}]"
      text
    end

    # Prints the same as print_short just with a list of all the queued
    # users as well.
    # @return [String] The status of this queue and list of queued users
    def print_long
      text = print_short
      text << ": #{@users.join(' ')}" unless @users.empty?
      text
    end

    # Removed print_ingame

    # Default to print_short for printing the queue object.
    # @return [String] The status of this queue
    # @see #print_short
    def to_s
      print_short
    end

    def to_hash
      {
        "queue_name": @name,
        "current_players": @users.length,
        "max_players": @max,
        "players": @users.map(&:name),
        "games": @games.map(&:to_hash)
      }
    end

    def to_json(*a)
      to_hash.to_json(*a)
    end
  end
end
