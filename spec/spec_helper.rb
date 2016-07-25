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

class TestUser < Cinch::User
  def send(text, notice = false)
    text = text.to_s
    split_start = @bot.config.message_split_start || ""
    split_end   = @bot.config.message_split_end   || ""
    command = notice ? "NOTICE" : "PRIVMSG"
    # Don't want to call mask on bot and deal with syncables so added manually.
    prefix = ":Bot!bot@network.com #{command} #{@name} :"

    text.lines.map(&:chomp).each do |line|
      splitted = split_message(line, prefix, split_start, split_end)

      splitted[0, (@bot.config.max_messages || splitted.size)].each do |string|
        @bot.irc.send("#{command} #{@name} :#{string}")
      end
    end
  end
end

class TestMessage < Cinch::Message
  def initialize(msg, bot, opts = {})
    # override the message-parsing stuff
    super(nil, bot)
    @message = msg
    @user = TestUser.new(opts.delete(:nick) { "test" }, bot)
    if opts.key?(:channel)
      @channel = Cinch::Channel.new(opts.delete(:channel), bot)
    end

    # set the message target
    @target = @channel || @user

    @bot.user_list.find_ensured(nil, @user.nick, nil)
  end
end

def set_test_message(raw, nick = "test")
  @message = TestMessage.new(
    ":#{nick}!#{nick}@network.com #{raw}",
    @bot,
    nick: nick
  )
end
