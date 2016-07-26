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
    @channel = @plugin.channel
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

  describe "!help" do
    before(:each) do
      set_test_message("PRIVMSG #channel :!help")
    end

    it "should send back the help for using the pug bot" do
      expect(@message.user).to receive(:notice).with(PugBot::HELP)
      send_message(@message)
    end
  end

  describe "!status" do
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

  describe "!start" do
    it "shouldn't allow me to start if I'm not opped" do
      set_test_message("PRIVMSG #channel :!start TestQ")
      expect(@message.user).to receive(:notice).with(PugBot::ACCESS_DENIED)
      send_message(@message)
    end

    it "should start default queue with supplied numbers" do
      set_test_message("PRIVMSG #channel :!start TestQ 10")
      user = @message.user
      @message.channel.add_user(user, ["o"])
      expect(@plugin.queue_list).to receive(:new_queue).with("TestQ", 10)
      send_message(@message)
    end

    it "shouldn't start if there is a game by that name already" do
      @queue1 = @plugin.queue_list.new_queue("TestQ")
      set_test_message("PRIVMSG #channel :!start TestQ 10")
      @message.channel.add_user(@message.user, ["o"])
      expect(@message.user).to receive(:notice).with(PugBot::NAME_TAKEN)
      send_message(@message)
    end

    it "shouldn't start with an odd number" do
      set_test_message("PRIVMSG #channel :!start TestQ 11")
      @message.channel.add_user(@message.user, ["o"])
      expect(@message.user).to receive(:notice).with(PugBot::ODD_NUMBER)
      send_message(@message)
    end

    it "shouldn't start with a number too large" do
      set_test_message("PRIVMSG #channel :!start TestQ 40")
      @message.channel.add_user(@message.user, ["o"])
      expect(@message.user).to receive(:notice).with(PugBot::TOO_LARGE)
      send_message(@message)
    end
  end

  describe "!add" do
    before(:each) do
      @queue1 = @plugin.queue_list.new_queue("TestQ")
      @queue2 = @plugin.queue_list.new_queue("TestQ2")
    end

    it "should join the default queue with no arguments" do
      set_test_message("PRIVMSG #channel :!add")
      user = @message.user
      expect(@queue1).to receive(:add).with(user)
      send_message(@message)
    end

    it "should join the game we give as an argument" do
      set_test_message("PRIVMSG #channel :!add 2")
      user = @message.user
      expect(@queue2).to receive(:add).with(user)
      send_message(@message)
    end

    it "should not accept an invalid argument" do
      set_test_message("PRIVMSG #channel :!add invalid")
      user = @message.user
      expect(@queue1).not_to receive(:add)
      expect(user).to receive(:notice).with(PugBot::QUEUE_NOT_FOUND)
      send_message(@message)
    end

    it "should not join the same queue twice" do
      set_test_message("PRIVMSG #channel :!add TestQ")
      user = @message.user
      @queue1.add(user)
      expect(@queue1).not_to receive(:add)
      expect(user).to receive(:notice).with(PugBot::ALREADY_IN_QUEUE)
      send_message(@message)
    end

    it "should not join if we are playing a game" do
      set_test_message("PRIVMSG #channel :!add TestQ")
      user = @message.user
      user.status = :ingame
      expect(@queue1).not_to receive(:add)
      expect(user).to receive(:notice).with(PugBot::YOU_ARE_PLAYING)
      send_message(@message)
    end

    it "should tell us if we are already in all queues" do
      set_test_message("PRIVMSG #channel :!add all")
      user = @message.user
      @queue1.add(user)
      @queue2.add(user)
      expect(@queue1).not_to receive(:add)
      expect(@queue2).not_to receive(:add)
      expect(user).to receive(:notice).with(PugBot::ALREADY_IN_ALL_QUEUES)
      send_message(@message)
    end

    it "should try joining all queues when supplied with argument all" do
      set_test_message("PRIVMSG #channel :!add all")
      user = @message.user
      expect(@queue1).to receive(:add).with(user)
      expect(@queue2).to receive(:add).with(user)
      send_message(@message)
    end

    it "should add to wait queue if we have just finished" do
      set_test_message("PRIVMSG #channel :!add 1")
      user = @message.user
      user.status = :finished
      expect(@queue1).not_to receive(:add).with(user)
      expect(@queue1).to receive(:add_wait).with(user)
      expect(user).to receive(:notice).with(PugBot::FINISHED_IN_QUEUE)
      send_message(@message)
    end
  end
end
