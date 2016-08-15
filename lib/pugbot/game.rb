module PugBot
  # This class is an object of a game actually being played, it is created when
  # a queue becomes full, given its players and a link back to the queue it came
  # from and remains until it is ended and finished in the queue.
  class Game
    # @return [Array<Cinch::User>] The list of users playing in this game
    attr_reader :users

    # @return [Symbol] The status of the game, either ingame or finished
    attr_reader :status

    # @return [Cinch::Timer] The timer counting down to the game being deleted
    attr_reader :timer

    # A game that currently exists, with users playing in it. Should not be
    # called directly, should automatically be called by Queue.ready
    # @param [Queue] queue The queue that this game has taken its players from
    # @param [Array<Cinch::User>] users The users playing in this game
    # @see Queue.ready
    def initialize(queue, users)
      @queue = queue
      @users = users
      @status = :ingame
      @queue.queue_list.plugin.integrate(:game_start, self, @queue)
    end

    # Ran when the game is manually finished, change the state of all users
    # who played and start a timer for them having to wait to join other
    # games.
    # @see BotPlugin.timer_game_end
    # @see #timeout
    # @return [void]
    def finish
      @users.each do |user|
        user.status = :finished
        user.track = false
      end
      @status = :finished
      @timer = @queue.queue_list.plugin.timer_game_end(self)
    end

    # Called after the timer after finishing this game has ended, set all the
    # players back to standby and have all games check their waiting pools
    # to account for all the changed statuses also remove from the queue's
    # list of games essentially deleting the object.
    # @return [void]
    def timeout
      @users.each { |user| user.status = :standby }
      @queue.queue_list.queues.each(&:check_waiters)
      @queue.finish(self)
    end

    # Sub a currently playing user for another, changing their states and
    # any other necessary options
    # @param [Cinch::User] user The user currently playing to be replaced
    # @param [Cinch::User] sub The user to be added to the game
    # @return [void]
    def sub(user, sub)
      @users.delete(user)
      user.status = :standby
      user.track = false
      @users.push(sub)
      sub.status = :ingame
      sub.track = true
      @queue.queue_list.remove_from_queues(sub)
    end

    # List the current players of this game
    # @return [String] A list of all the users
    def to_s
      if @status == :ingame
        "Current players: #{@users.join(' ')}"
      else
        "Just finished: #{@users.join(' ')}"
      end
    end
  end
end
