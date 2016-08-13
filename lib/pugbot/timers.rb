module PugBot
  # The plugin to be imported into a cinch bot instance that actually interprets
  # the users input, tracks players and controls nearly all running of the pug
  # bot itself.
  class BotPlugin
    # When a game ends, start a timer until the game is actually deleted by
    # Game.timeout and the players can join other queues again.
    # @param [Game] game The game that has just finished.
    # @return [Cinch::Timer] The timer that has just been created.
    # @see Game.timeout
    def timer_game_end(game)
      Timer(FINISH_TIMEOUT, shots: 1) { game.timeout }
    end

    # When a user leaves the channel, start a timer until they should be
    # removed from their queues.
    # @param [Cinch::User] user The user that has left the channel
    # @return [Cinch::Timer] The timer that has just been created
    def timer_user_leave(user)
      Timer(LEAVE_TIMEOUT, shots: 1) { user_timeout(user) }
    end

    # When a tracked user's timeout runs out, if they are alert that we may need
    # a sub otherwise remove from all queues and inform.
    # @param [Cinch::User] user The user that has timed out
    # @return [void]
    def user_timeout(user)
      return unless user.track
      if user.status == :ingame
        send format(DISCONNECTED_INGAME, user.nick, user.nick)
      else
        send format(DISCONNECTED, user.nick)
        user.track = false
        @queue_list.remove_from_queues(user)
        update_topic
      end
    end
  end
end
