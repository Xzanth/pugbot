module PugBot
  # This class is an object of a game actually being played, it is created when
  # a queue becomes full, given its players and a link back to the queue it came
  # from and remains until it is ended and finished in the queue.
  class Game
    # @return [Array<Cinch::User>] The list of users playing in this game
    attr_reader :users

    # @param [Queue] queue The queue that this game has taken its players from
    # @param [Array<Cinch::User>] users The users playing in this game
    # @see Queue.ready
    def initialize(queue, users)
      @queue = queue
      @users = users
    end

    # Ran when the game is manually finished, change the state of all users
    # who played and start a timer for them having to wait to join other
    # games.
    # @see #timeout
    def finish
      @users.each do |user|
        user.status = :finished
        user.track = false
      end
      $timers.after(30) { timeout }
    end

    # Called after 30s have passed since this game has finished, set all the
    # players back to standby and have all games check their waiting pools
    # to account for all the changed statuses also remove from the queue's
    # list of games essentially deleting the object.
    def timeout
      @users.each { |user| user.status = :standby }
      @queue.queue_list.each(&:check_waiters)
      @queue.finish(self)
    end

    # Sub a currently playing user for another, changing their states and
    # any other necessary options
    # @param [Cinch::User] user The user currently playing to be replaced
    # @param [Cinch::User] sub The user to be added to the game
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
      "Current players: #{@users.join(' ')}"
    end
  end
end
