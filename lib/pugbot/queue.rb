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

    # Join a queue, by testing if we can and then either adding,
    # add_waiting. Returns the status of the function so that the user can
    # be notified.
    # @param [Cinch::User] user The user to try joining with
    # @return [Symbol] The status of our attempt to join
    def join(user)
      return :already_queued  if listed?(user)
      return :already_playing if ingame?(user)
      return :already_waiting if listed_wait?(user)
      return :ingame          if user.status == :ingame

      if user.status == :finished
        add_wait(user)
        return :added_wait
      else
        add(user)
        ready
        return :added
      end
    end

    # Leave a queue, by testing if we can then removing ourselves.
    # @param [Cinch::User] user The user to try joining with
    # @return [Symbol] The status of our attempt to leave
    def leave(user)
      return :already_playing if ingame?(user)
      return :not_queued unless listed?(user)
      remove(user)
      :removed
    end

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

    # Test if a user is in any game being played in this queue.
    # @return [Boolean] Whether they are in a game or not
    def ingame?(user)
      @games.any { |game| game.users.include?(user) }
    end

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
        @queue_list.plugin.channel.send(text)
        # $slack_client.web_client.chat_postMessage(
        #   channel: "#pugs",
        #   text: "#{text} - sign up for the next on "\
        #   "<http://webchat.quakenet.org/?channels=midair.pug|#midair.pug>",
        #   as_user: true
        # )
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
        @channel.send("Users have been randomized into queue")
        ready
        @queue_list.set_topic
      end
    end

    # Just print the queue name, whether there is one in progress or not
    # (and the number if there are multiple) and the number of players and subs.
    # @return [String] The status of this queue
    def print_short
      text = "#{@name} - "
      if @games.length == 1
        text << "IN GAME - "
      elsif @games.length > 1
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

    # Print all the games currently being played, with a list of all the
    # players in each
    # @return [String] The formatted list of all games with players
    def print_ingame
      return "" if @games.empty?
      return "#{@name} - " + @games[0].to_s if @games.length == 1
      text = ""
      @games.each.with_index do |game, index|
        text += "#{@name} #{index + 1} - #{game}\n"
      end
      text
    end

    # Default to print_short for printing the queue object.
    # @return [String] The status of this queue
    # @see #print_short
    def to_s
      print_short
    end
  end
end
