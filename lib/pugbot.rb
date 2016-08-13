require "cinch"
require "pugbot/queue_list"
require "pugbot/queue"
require "pugbot/game"
require "pugbot/handlers"
require "pugbot/constants"
require "pugbot/cinch/user"

# This module contains the pugbot plugin and all the associated classes needed
# to organise, create and monitor games being run.
module PugBot
  # The plugin to be imported into a cinch bot instance that actually interprets
  # the users input, tracks players and controls nearly all running of the pug
  # bot itself.
  class BotPlugin
    include Cinch::Plugin

    # @return [QueueList] The list of queues for this plugin
    attr_reader :queue_list

    # @return [Cinch::Channel] The channel that this plugin is being run in
    attr_reader :channel

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
    match(/remove (\S+)\s?(\d+|\w+)?$/,   method: :remove)
    match(/end\s?(\d+|\w+)?$/,            method: :end)
    match(/finish\s?(\d+|\w+)?$/,         method: :finish)
    match(/sub (.+) (.+)$/,               method: :sub)
    match(/shutdown$/,                    method: :shutdown)
  end
end
