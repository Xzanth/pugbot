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
      expect(@plugin.queue_list.queues).to be_empty
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

    it "should not join a game if we are playing a game" do
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

    it "should add to wait queue if we have just finished and try to join" do
      set_test_message("PRIVMSG #channel :!add 1")
      user = @message.user
      user.status = :finished
      expect(@queue1).not_to receive(:add).with(user)
      expect(@queue1).to receive(:add_wait).with(user)
      expect(user).to receive(:notice).with(PugBot::FINISHED_IN_QUEUE)
      send_message(@message)
    end

    it "should add to all wait queues if we have just finished and add all" do
      set_test_message("PRIVMSG #channel :!add all")
      user = @message.user
      user.status = :finished
      expect(@queue1).not_to receive(:add).with(user)
      expect(@queue1).to receive(:add_wait).with(user)
      expect(@queue2).not_to receive(:add).with(user)
      expect(@queue2).to receive(:add_wait).with(user)
      expect(user).to receive(:notice).with(PugBot::FINISHED_IN_QUEUE)
      send_message(@message)
    end
  end

  describe "!del" do
    before(:each) do
      @queue1 = @plugin.queue_list.new_queue("TestQ")
      @queue2 = @plugin.queue_list.new_queue("TestQ2")
    end

    it "should delete from all games with no arguments" do
      set_test_message("PRIVMSG #channel :!del")
      user = @message.user
      @queue1.add(user)
      @queue2.add(user)
      expect(@message).to receive(:reply).with(
        format(PugBot::LEFT_ALL, user.nick)
      )
      send_message(@message)
      expect(@queue1.users).to be_empty
      expect(@queue2.users).to be_empty
    end

    it "should only delete from one game with an argument" do
      set_test_message("PRIVMSG #channel :!del 2")
      user = @message.user
      @queue1.add(user)
      @queue2.add(user)
      expect(@message).to receive(:reply).with(
        format(PugBot::LEFT, user.nick, @queue2.name)
      )
      send_message(@message)
      expect(@queue1.users).to include(user)
      expect(@queue2.users).to be_empty
    end

    it "should not let us delete if we are playing a game" do
      set_test_message("PRIVMSG #channel :!del 1")
      user = @message.user
      @queue1.add(user)
      user.status = :ingame
      expect(user).to receive(:notice).with(PugBot::YOU_ARE_PLAYING)
      send_message(@message)
      expect(@queue1.users).to include(user)
    end

    it "should not accept an invalid argument" do
      set_test_message("PRIVMSG #channel :!del 3")
      user = @message.user
      @queue1.add(user)
      @queue2.add(user)
      expect(user).to receive(:notice).with(PugBot::QUEUE_NOT_FOUND)
      send_message(@message)
      expect(@queue1.users).to include(user)
      expect(@queue2.users).to include(user)
    end

    it "should tell us if we are not in the specified queue" do
      set_test_message("PRIVMSG #channel :!del 2")
      user = @message.user
      @queue1.add(user)
      expect(user).to receive(:notice).with(PugBot::YOU_NOT_IN_QUEUE)
      send_message(@message)
      expect(@queue1.users).to include(user)
      expect(@queue2.users).not_to include(user)
    end

    it "should tell us if we are not in any queues on del all" do
      set_test_message("PRIVMSG #channel :!del")
      user = @message.user
      expect(user).to receive(:notice).with(PugBot::YOU_NOT_IN_ANY_QUEUES)
      send_message(@message)
    end
  end

  describe "!remove" do
    before(:each) do
      @queue1 = @plugin.queue_list.new_queue("TestQ")
      @queue2 = @plugin.queue_list.new_queue("TestQ2")
    end

    it "shouldn't allow me to remove if I'm not opped" do
      set_test_message("PRIVMSG #channel :!remove Ben TestQ")
      expect(@message.user).to receive(:notice).with(PugBot::ACCESS_DENIED)
      send_message(@message)
    end

    it "should remove a user from all if supplied with no arguments" do
      user2 = Cinch::User.new("test2", @bot)
      @queue1.add(user2)
      @queue2.add(user2)
      set_test_message("PRIVMSG #channel :!remove test2")
      user = @message.user
      @message.channel.add_user(user, ["o"])
      expect(@message).to receive(:reply).with(
        format(PugBot::REMOVED, user2.nick, "all queues", user.nick)
      )
      send_message(@message)
      expect(@queue1.users).to be_empty
      expect(@queue2.users).to be_empty
    end
  end
end
