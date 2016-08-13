module PugBot
  # The plugin to be imported into a cinch bot instance that actually interprets
  # the users input, tracks players and controls nearly all running of the pug
  # bot itself.
  class BotPlugin
    # When a game ends, start a timer until the game is actually deleted by
    # Game.timeout and the players can join other queues again.
    # @param <Game> game The game that has just finished.
    # @return <Cinch::Timer> The timer that has just been created.
    # @see Game.timeout
    def timer_game_end(game)
      Timer(FINISH_TIMEOUT, shots: 1) { game.timeout }
    end
  end
end
