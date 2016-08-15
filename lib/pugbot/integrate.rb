module PugBot
  # The plugin to be imported into a cinch bot instance that actually interprets
  # the users input, tracks players and controls nearly all running of the pug
  # bot itself.
  class BotPlugin
    def integrate(type, *args)
      return unless config[:integrate]
      case type
      when :game_start
        @bot.handlers.dispatch(
          :integrate,
          nil,
          :slack,
          channel: "#pugs",
          text: format(SLACK_GAME_START, args[1].name, args[0].users.join(" "),
                       config[:link]),
          as_user: true
        )
      end
    end
  end
end
