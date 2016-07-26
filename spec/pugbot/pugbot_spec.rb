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
      @queue1 = @plugin.queue_list.new_queue("TestQ")
      @queue2 = @plugin.queue_list.new_queue("TestQ2", 2)
    end

    it "should tell me if I give invalid queue name" do
      set_test_message("PRIVMSG #channel :!status invalid")
      expect(@message.user).to receive(:notice).with(PugBot::QUEUE_NOT_FOUND)
      send_message(@message)
    end

    it "should tell me if I give invalid number" do
      set_test_message("PRIVMSG #channel :!status 3")
      expect(@message.user).to receive(:notice).with(PugBot::QUEUE_NOT_FOUND)
      send_message(@message)
    end

    it "should tell me about a queue if I give the name" do
      set_test_message("PRIVMSG #channel :!status TestQ")
      expect(@message.user).to receive(:notice).with("TestQ - [0/10]")
      send_message(@message)
    end

    it "should tell me about a queue if I give the number" do
      set_test_message("PRIVMSG #channel :!status 2")
      expect(@message.user).to receive(:notice).with("TestQ2 - [0/2]")
      send_message(@message)
    end

    it "should tell me about the default queue without any arguments" do
      set_test_message("PRIVMSG #channel :!status")
      expect(@message.user).to receive(:notice).with("TestQ - [0/10]")
      send_message(@message)
    end

    it "should tell me about all queues with argument all" do
      set_test_message("PRIVMSG #channel :!status all")
      user = @message.user
      allow(user).to receive(:notice)
      send_message(@message)
      expect(user).to have_received(:notice).exactly(2).times
      ["TestQ - [0/10]", "TestQ2 - [0/2]"].each do |msg|
        expect(user).to have_received(:notice).with(msg)
      end
    end

    it "should tell me the players queued" do
      set_test_message("PRIVMSG #channel :!status TestQ")
      user = @message.user
      @queue1.add(user)
      expect(user).to receive(:notice).with("TestQ - [1/10]: #{user}")
      send_message(@message)
    end

    it "should tell me about a game currently underway" do
      set_test_message("PRIVMSG #channel :!status TestQ2")
      user = @message.user
      user2 = Cinch::User.new("nick2", @bot)
      @queue2.add(user)
      @queue2.add(user2)
      allow(user).to receive(:notice)
      send_message(@message)
      expect(user).to have_received(:notice).exactly(2).times
      msgs = [
        "TestQ2 - IN GAME - [0/2]",
        "Game 1 - Current players: test nick2"
      ]
      msgs.each { |msg| expect(user).to have_received(:notice).with(msg) }
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
