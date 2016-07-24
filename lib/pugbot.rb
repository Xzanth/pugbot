require_relative "pugbot/queue_list"
require_relative "pugbot/queue"
require_relative "pugbot/game"

module PugBot
  # The plugin to be imported into a cinch bot instance that actually interprets
  # the users input, tracks players and controls nearly all running of the pug
  # bot itself.
  class BotPlugin
    include Cinch::Plugin

    ACCESS_DENIED = "Access denied - must be a channel operator.".freeze
    USERS_NOT_FOUND = "One or more users not found.".freeze
    NOT_PLAYING = "is not playing a game.".freeze
    ALREADY_PLAYING = "is already playing a game.".freeze
    QUEUE_NOT_FOUND = "Queue not found.".freeze
    NOT_IN_QUEUE = "You are not in this queue.".freeze
    YOU_NOT_IN_QUEUE = "This user is not in this queue.".freeze
    NOT_IN_ANY_QUEUES = "This user is not in any queues.".freeze
    YOU_NOT_IN_ANY_QUEUES = "This user is not in any queues.".freeze
    REMOVED = "has been removed".freeze
    LEFT = "has abandoned".freeze
    LEFT_ALL = "has abandoned all queues".freeze
    YOU_ARE_PLAYING = "Cannot perform this action while you are playing a"\
    " game.".freeze
    ALREADY_IN_QUEUE = "You are already in this queue.".freeze
    NAME_TAKEN = "A queue with that name already exists.".freeze
    ODD_NUMBER = "Games must have an even number of players.".freeze
    TOO_LARGE = "Games must have 32 or less players.".freeze
    TOO_SMALL = "Games must have at least 6 players.".freeze
    HELP = "Supported commands are: !help, !status (all|gamename|num), !finish"\
    " (gamename|num), !add (all|gamename|num), !del (all|gamename|num), !subs"\
    " and !sub (name1) (name2). And for channel operators: !start gamename"\
    " (num), !end (gamename|num) and !remove name.".freeze
    EDIT_TOPIC = "Please don't edit the topic.".freeze
    I_AM_BOT = "I am a bot please direct all questions/comments to"\
    " Xzanth".freeze
    WELCOME = "Welcome to #{$channel} - sign up for games by typing '!add"\
  " nameofgame' and remove yourself from queues with '!del'".freeze

    listen_to :connect, method: :setup
    listen_to :topic,   method: :topic_changed
    listen_to :private, method: :private_message
    listen_to :join,    method: :joined_channel
    listen_to :leaving, method: :left_channel

    match(/help$/,                        method: :help)
    match(/status\s?(\d+|\w+)?$/,         method: :status)
    match(/start ([a-zA-Z]+)\s?(\d+)?$/,  method: :start)
    match(/add\s?(\d+|\w+)?$/,            method: :add)
    match(/del\s?(\d+|\w+)?$/,            method: :del)
    match(/remove (.+)\s?(\d+|\w+)?$/,    method: :remove)
    match(/end\s?(\d+|\w+)?$/,            method: :end)
    match(/finish\s?(\d+|\w+)?$/,         method: :finish)
    match(/sub (.+) (.+)$/,               method: :sub)
    match(/shutdown$/,                    method: :shutdown)

    # Set up variables, called when the bot first connects to irc. Start an
    # array of names to not pmsg back.
    # @return [void]
    def setup(*)
      @names = ["Q"]
    end

    # Don't allow anyone else to change the channel topic, warn them with
    # a notice.
    # @return [void]
    def topic_changed(m)
      return if m.user.nick == bot.nick
      m.user.notice EDIT_TOPIC
    end

    # Inform anyone we haven't informed previously that we are a bot when they
    # private message us.
    # @return [void]
    def private_message(m)
      nick = m.user.nick
      m.reply I_AM_BOT @names.push(nick) unless @names.include?(nick)
    end

    # When a user joins a channel, welcome them and if they are being tracked
    # cancel their countdown, if it is us the bot, then set the global variable
    # $channel.
    # @return [void]
    def joined_channel(m)
      user = m.user
      user.rejoined if user.track

      $channel = m.channel if user.nick == bot.nick
      user.notice WELCOME
    end

    # When a tracked user leaves the channel start a timer before they are
    # removed from queues.
    # @return [void]
    def left_channel(m)
      user = m.user
      user.left if user.track
    end

    ############################################################################
    # @!group !help

    # Give information to the user requesting help.
    # @todo Proper help, add argument to give help about specific commands
    # @return [void]
    def help(m)
      m.user.notice HELP
    end

    ############################################################################
    # @!group !status

    # Parse a status command, give status about a queue specified by arg. Give
    # info about the default queue if no arg is given.
    # @param [String] arg Describes the queue to give info about
    # @return [void]
    # @see Queue.print_long
    def status(m, arg)
      queue = $queue_list.find_queue_by_arg(arg)
      user = m.user
      $queue_list.queues.each { |q| user.notice q.print_long } if arg == "all"
      return user.notice QUEUE_NOT_FOUND if queue.nil?
      queue.print_long
    end

    ############################################################################
    # @!group !start

    # Parse a start command, which can only be run by operators. Check if
    # a queue already exists with that name then if the number is acceptable
    # issue a call to start a new queue. Which will default to a max player
    # number of 10 if num is not given.
    # @param [String] name The name the queue should have
    # @param [String] num A string of the number of max players for the queue
    # @return [void]
    # @see QueueList.new_queue
    def start(m, name, num)
      num = num.to_i
      user = m.user
      return user.notice ACCESS_DENIED unless m.channel.opped?(user.nick)
      return user.notice NAME_TAKEN if $queue_list.find_queue_by_name(name)
      return user.notice ODD_NUMBER if num.odd?
      return user.notice TOO_LARGE if num > 32
      return user.notice TOO_SMALL if num < 6
      $queue_list.new_queue(name, num)
    end

    ############################################################################
    # @!group !add

    # Parse an add command, adding to the default if no argument is supplied
    # otherwise parsing the arg variable and adding to specific queues.
    # @param [String] arg Describes the queue to add the user to
    # @return [void]
    # @see #try_join
    # @see #try_join_all
    def add(m, arg)
      queue = $queue_list.find_queue_by_arg(arg)
      user = m.user
      return try_join_all(user) if arg == "all"
      return user.notice QUEUE_NOT_FOUND if queue.nil?
      return user.notice ALREADY_IN_QUEUE if queue.listed_either?(user)
      try_join(user, queue)
    end

    # Try joining a queue, fail if already playing. If have just finished only
    # add to the wait queue otherwise add to normal queue.
    # @param [Cinch::User] user The user that is trying to join
    # @param [Queue] queue The queue they are trying to join
    # @return [void]
    # @see add
    # @see Queue.add
    # @see Queue.add_wait
    def try_join(user, queue)
      return user.notice YOU_ARE_PLAYING if playing?(user)
      if user.status == :finished
        user.notice FINISHED_IN_QUEUE
        queue.add_wait(user)
      else
        queue.add(user)
      end
    end

    # Try joining all queues the user is not already queued for. Fail if already
    # playing and add to the wait queue if just finished otherwise add to normal
    # queue.
    # @param [Cinch::User] user The user trying to join all queues
    # @return [void]
    # @see add
    # @see Queue.add
    # @see Queue.add_wait
    def try_join_all(user)
      queues = $queue_list.queues.select { |q| !q.listed_either?(user) }
      return user.notice YOU_ARE_PLAYING if playing?(user)
      return user.notice ALREADY_IN_ALL_QUEUES if queues.empty?
      if user.status == :finished
        user.notice FINISHED_IN_QUEUE
        queues.each { |q| q.add_wait(user) }
      else
        queue.add(user)
        queues.each { |q| q.add(user) }
      end
    end

    ############################################################################
    # @!group !del

    # Parse a del command either trying to remove from all queues with no
    # arguments or just removing from a specific queue according to arg.
    # @param [String] arg Describes the queue to remove the user from
    # @return [void]
    # @see Queue.remove
    def del(m, arg)
      queue = $queue_list.find_queue_by_arg(arg)
      user = m.user
      return user.notice YOU_ARE_PLAYING if playing?(user)
      return del_from_all(m, user) if arg.nil? || arg == "all"
      return user.notice QUEUE_NOT_FOUND if queue.nil?
      return user.notice YOU_NOT_IN_QUEUE unless queue.listed_either?(user)
      m.reply "#{user.nick} #{LEFT} #{queue.name}"
      queue.remove(user)
    end

    # Delete a user from all the queues they are queued in, noticing them if
    # they are not in any, otherwise announcing that they have left all queues.
    # @param [Cinch::User] user The user that wishes to remove themself
    # @return [void]
    # @see #del
    # @see Queue.remove
    def del_from_all(m, user)
      queues = $queue_list.queues.select { |q| q.listed_either?(user) }
      return user.notice YOU_NOT_IN_ANY_QUEUES if queues.empty?
      queues.each { |q| q.remove(user) }
      m.reply "#{user.nick} #{LEFT_ALL}"
    end

    ############################################################################
    # @!group !remove

    # Parse a remove command, only allowing ops to execute and removing the user
    # from all queues if no argument is specified, otherwise parsing the
    # argument and removing the user from the specified queue.
    # @param [String] name The nick of the user to be removed
    # @param [String] arg Describes the queue to remove the user from
    # @return [void]
    # @see #remove_from_all
    # @see #remove_from_queue
    def remove(m, name, arg)
      queue = $queue_list.find_queue_by_arg(arg)
      user = User(name)
      nick = m.user.nick
      return m.user.notice ACCESS_DENIED unless m.channel.opped?(nick)
      return m.user.notice USERS_NOT_FOUND if user.nil?
      return remove_from_all(m, user) if arg.nil? || arg == "all"
      return m.user.notice QUEUE_NOT_FOUND if queue.nil?
      remove_from_queue(m, user, queue)
    end

    # Remove a user from a specified queue and reply to the channel, or notice
    # the remover and return :not_in_queue if the user is not in the queue.
    # @param [Cinch::User] user The user to be removed
    # @param [Queue] queue The queue to remove the user from
    # @return [Symbol] :not_in_queue if the user is not in the queue
    # @see #remove
    # @see Queue.remove
    def remove_from_queue(m, user, queue)
      unless queue.listed_either?(user)
        m.user.notice NOT_IN_QUEUE
        return :not_in_queue
      end
      queue.remove(user)
      m.reply "#{user.nick} #{REMOVED} from #{queue.name} by #{m.user.nick}"
    end

    # Remove a user from all queues, run {#remove_from_queue} on each queue in
    # queuelist and if they all return :not_in_queue then the user wasn't in any
    # queues and we should alert the remover.
    # @param [Cinch::User] user The user to be removed
    # @return [void]
    # @see #remove
    # @see #remove_from_queue
    # @see Queue.remove
    def remove_from_all(m, user)
      any = !$queue_list.queues.all? do |q|
        remove_from_queue(m, user, q) == :not_in_queue
      end
      m.user.notice NOT_IN_ANY_QUEUES unless any
      m.reply "#{user.nick} #{REMOVED} by #{nick}"
    end

    ############################################################################
    # @!group !end

    # End a queue, a command for operators that deletes a queue from the
    # queuelist and allows all current players to immeditaely join new queues.
    # @param [String] arg The queue to delete.
    # @return [void]
    # @see QueueList.remove
    def end(m, arg)
      queue = $queue_list.find_queue_by_arg(arg)
      return m.user.notice ACCESS_DENIED unless m.channel.opped?(m.user.nick)
      return m.user.notice QUEUE_NOT_FOUND if queue.nil?
      queue.games.users.each { |user| user.status = :standby }
      $queue_list.remove(queue)
    end

    ############################################################################
    # @!group !finish

    # Finish the game currently being played.
    # @todo Currently finishes all games which is not intended behaviour
    # @param [String] arg The queue to finish the games in
    # @return [void]
    # @see Game.finish
    def finish(m, arg)
      queue = $queue_list.find_queue_by_arg(arg)
      return m.user.notice QUEUE_NOT_FOUND if queue.nil?
      queue.games.each(&:finish)
    end

    ############################################################################
    # @!group !sub

    # Sub a user assigned to a game with one not assigned to a game, check that
    # the input is correct and then run the {#swap} function.
    # @param [String] user The nick of the user in a game
    # @param [String] sub The nick of the user not in a game
    # @return [void]
    # @see #swap
    def sub(m, user, sub)
      user_u = User(user)
      sub_u = User(sub)
      return m.user.notice USERS_NOT_FOUND if user_u.nil? || sub_u.nil?
      return m.user.notice "#{user} #{NOT_PLAYING}" unless playing?(user)
      return m.user.notice "#{sub} #{ALREADY_PLAYING}" if playing?(sub)
      swap(user_u, sub_u)
      $queue_list.send "#{user} has been subbed with #{sub} by #{m.user.nick}"
      $queue_list.set_topic
    end

    # Swap too users, one playing and one not.
    # @param [Cinch::User] user1 The user currently playing a game
    # @param [Cinch::User] user2 The user currently not playing a game
    # @return [void]
    # @see #sub
    # @see Queue.sub
    # @see Queue.remove
    def swap(user1, user2)
      user2.set_status(:ingame)
      user1.set_status(:standby)
      $queue_list.find_game_playing(user1).sub(user1, user2)
      $queue_list.queues.each { |q| q.remove(user2) }
    end

    ############################################################################
    # @!group !shutdown

    # Quit the program immediately, can only be performed by operator.
    # @return [void]
    def shutdown(m)
      return m.user.notice ACCESS_DENIED unless m.channel.opped?(m.user.nick)
      m.reply "Bot shut down by #{m.user.nick}"
      abort "Program killed by #{m.user.nick}"
    end

    ############################################################################
    # @!group HelperFunctions

    # Is a user currently playing in a game?
    # @param [String] user The nick of the user to test
    # @return [Boolean] Whether or not they are playing
    def playing?(user)
      user.status == :ingame
    end

    ############################################################################
  end
end
