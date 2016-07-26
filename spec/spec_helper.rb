require "simplecov"
require "codeclimate-test-reporter"

SimpleCov.start CodeClimate::TestReporter.configuration.profile do
  formatter SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::HTMLFormatter,
      CodeClimate::TestReporter::Formatter
    ]
  )
end

require "cinch"
require "pugbot"

class TestBot < Cinch::Bot
  attr_reader :raw_log

  def initialize(*args)
    super
    @irc = TestIRC.new
    @loggers = Cinch::LoggerList.new
    @raw_log = []
  end

  def raw(command)
    @raw_log << command
  end

  def mask
    Cinch::Mask.new("Bot!bot@network.com")
  end
end

class TestIRC
  attr_reader :isupport
  attr_reader :network

  def initialize
    @isupport = Cinch::ISupport.new
    @network = TestNetwork.new
  end

  def send(*)
  end
end

class TestNetwork
  def ngametv?
    false
  end

  def whois_only_one_argument?
    false
  end
end

class TestMessage < Cinch::Message
  def initialize(msg, bot, opts = {})
    super(msg, bot)
    @user = Cinch::User.new(opts.delete(:nick) { "test" }, bot)

    if opts.key?(:channel)
      @channel = Cinch::Channel.new(opts.delete(:channel), bot)
    end

    # set the message target
    @target = @channel || @user
  end

  def numeric_reply?
    false
  end
end

def set_test_message(raw, nick = "test", channel = true)
  opts = { nick: nick }
  opts[:channel] = "#channel" if channel
  @message = TestMessage.new(
    ":#{nick}!#{nick}@network.com #{raw}",
    @bot,
    opts
  )
end

def send_message(message, event = :message)
  handlers = message.bot.handlers

  # Deal with secondary event types
  # See http://rubydoc.info/github/cinchrb/cinch/file/docs/events.md
  events = [:catchall, event]

  # If the message has a channel add the :channel event
  events << :channel unless message.channel.nil?

  # If the message is :private also trigger :message
  events << :message if events.include?(:private)

  # Dispatch each of the events to the handlers
  events.each { |e| handlers.dispatch(e, message) }

  # join all of the freaking threads, like seriously
  # why is there no option to dispatch synchronously
  handlers.each do |handler|
    handler.thread_group.list.each(&:join)
  end
end
