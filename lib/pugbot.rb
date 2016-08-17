require "cinch"
require "cinch/commands"
require "pugbot/timers"
require "pugbot/queue_list"
require "pugbot/queue"
require "pugbot/game"
require "pugbot/integrate"
require "pugbot/handlers"
require "pugbot/constants"
require "pugbot/cinch/user"
require "pugbot/storage/models"

# This module contains the pugbot plugin and all the associated classes needed
# to organise, create and monitor games being run.
module PugBot
  # The plugin to be imported into a cinch bot instance that actually interprets
  # the users input, tracks players and controls nearly all running of the pug
  # bot itself.
  class BotPlugin
    include Cinch::Plugin
    include Cinch::Commands

    # @return [QueueList] The list of queues for this plugin
    attr_reader :queue_list

    # @return [Cinch::Channel] The channel that this plugin is being run in
    attr_reader :channel

    listen_to :connect, method: :setup
    listen_to :topic,   method: :topic_changed
    listen_to :private, method: :private_message
    listen_to :join,    method: :joined_channel
    listen_to :leaving, method: :left_channel

    command :status, [{ name: "QUEUE", format: :string, optional: true }],
            summary: "Get the status of the default or specified queue/queues",
            description: "Can take a queue name/number or 'all' as an"\
            " argument, and will print the status of the specified"\
            " queue/queues or the default one when no argument is supplied."
    command :add, [{ name: "QUEUE", format: :string, optional: true }],
            summary: "Add to the default or specified queue",
            description: "Add yourself to either the default queue when"\
            " supplied with no arguments or when QUEUE is a queue name or"\
            " number or 'all', add to the corresponding queue/queues."
    command :del, [{ name: "QUEUE", format: :string, optional: true }],
            summary: "Remove from all queues or specified queue",
            descripion: "Remove yourself from all queues if supplied with no"\
            " arguments otherwise remove from the queue with name or number:"\
            " QUEUE."
    command :finish,
            [{ name: "QUEUE", format: :string, optional: true },
             { name: "GAME_NUM", format: :integer, optional: true }],
            summary: "Finish the game you were playing in or the game you"\
            " specify",
            description: "If you were just playing a game, !finish with no"\
            " arguments will let the bot know that game has finished"\
            " otherwise you must specify the game that has finished with"\
            " either the queue name or number as QUEUE and the game number as"\
            " GAME_NUM."
    command :sub,
            [{ name: "PLAYER", format: :string, optional: false },
             { name: "SUB", format: :string, optional: false }],
            summary: "Replace PLAYER currently in a game with SUB who is"\
            " currently not",
            description: "For a game in progress, substitute a user currently"\
            " in the game named PLAYER with a user named SUB not currently"\
            " playing any game."
    command :ts3, [],
            summary: "Get the ts3 info",
            description: "Reply to the message with teamspeak3 connection"\
            " information for all users in the channel."
    command :start,
            [{ name: "QUEUE_NAME", format: :string, optional: false },
             { name: "NUM_PLAYERS", format: :integer, optional: true }],
            summary: "Operators only. Start a new queue for specified number"\
            " of players",
            description: "Operators only. Create a new queue with name"\
            " QUEUE_NAME that will start a game when NUM_PLAYERS number of"\
            " users !add to it."
    command :remove,
            [{ name: "NAME", format: :string, optional: false },
             { name: "QUEUE", format: :string, optional: true }],
            summary: "Operators only. Remove a specified user from all queues"\
            " or the specified queue",
            description: "Operators only. Remove the specified user: NAME from"\
            " all queues if supplied with no arguments otherwise from the"\
            " queue with name or number: QUEUE."
    command :end, [{ name: "QUEUE", format: :string, optional: false }],
            summary: "Operators only. Delete the specified queue",
            description: "Operators only. Delete the queue with name or"\
            " number: QUEUE."
    command :shutdown, [],
            summary: "Operators only. Shut down the whole bot",
            description: "Operators only. Will shut down the whole bot so"\
            " please only use if bot is spamming or otherwise causing"\
            " inconvenience to the users of the channel."

    # Send message to plugin channel. Quick helper method to stop send methods
    # getting too long.
    # @param [String] text The text to send to the channel
    # @return [void]
    def send(text)
      @channel.send(text)
    end
  end
end
