require "spec_helper"

describe PugBot::BotPlugin do
  before(:each) do
    @bot = TestBot.new do
      configure do |config|
        config.plugins.options[PugBot::BotPlugin] = {
          channel: "#channel"
        }
      end
    end
    @plugin = PugBot::BotPlugin.new(@bot)
    @plugin.setup
  end

  describe "private message" do
    it "should respond first time with info" do
      set_test_message("PRIVMSG #{@bot.nick} :text", "test", false)
      expect(@message).to receive(:reply).with(PugBot::I_AM_BOT)
      send_message(@message, :private)
    end

    it "should not respond to Q" do
      set_test_message("PRIVMSG #{@bot.nick} :text", "Q", false)
      expect(@message).not_to receive(:reply)
      send_message(@message, :private)
    end

    it "should not respond to same person twice" do
      set_test_message("PRIVMSG #{@bot.nick} :text", "test", false)
      send_message(@message, :private)
      set_test_message("PRIVMSG #{@bot.nick} :text", "test", false)
      expect(@message).not_to receive(:reply)
      send_message(@message, :private)
    end
  end

  describe "topic" do
    it "should not allow others to edit the topic" do
      set_test_message("TOPIC #channel :changed the topic")
      expect(@message.user).to receive(:notice).with(PugBot::EDIT_TOPIC)
      send_message(@message, :topic)
    end

    it "should change the topic back after being edited" do
      # TODO
    end

    it "should allow the bot to edit the topic" do
      set_test_message("TOPIC #channel :changed the topic", @bot.nick)
      expect(@message.user).not_to receive(:notice)
      send_message(@message, :topic)
    end
  end

  describe "join" do
    it "should welcome people joining" do
      set_test_message("JOIN #channel")
      expect(@message.user).to(
        receive(:notice).with(format(PugBot::WELCOME, "#channel"))
      )
      send_message(@message, :join)
    end

    it "should cancel timeouts for tracked users" do
      # TODO
    end
  end

  describe "left" do
    it "should start countdown for tracked users" do
      # TODO
    end
  end

  describe "status" do
    before(:each) do
      $queue_list = PugBot::QueueList.new
      $queue_list.new_queue("Test")
    end

    it "should tell me if I give invalid queue name" do
      set_test_message("PRIVMSG #channel :!status invalid")
      expect(@message.user).to receive(:notice).with(PugBot::QUEUE_NOT_FOUND)
      send_message(@message)
    end
  end

  describe "!help" do
    before(:each) do
      set_test_message("PRIVMSG #channel :!help")
    end

    it "should send back the help for using the pug bot" do
      expect(@message.user).to receive(:notice).with(PugBot::HELP)
      send_message(@message)
    end
  end
end
