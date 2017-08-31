require "spec_helper"

describe PugBot::BotPlugin do
  before(:each) do
    @bot = TestBot.new do
      configure do |config|
        config.plugins.options[PugBot::BotPlugin] = {
          channel: "#channel",
          integrate: true
        }
      end
    end
    @plugin = PugBot::BotPlugin.new(@bot)
    @plugin.setup
    @channel = @plugin.channel
    @user1 = TestUser.new("test1", @bot)
    @user2 = TestUser.new("test2", @bot)
    @user3 = TestUser.new("test3", @bot)
    @user4 = TestUser.new("test4", @bot)
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
      expect(@message.user).to receive(:notice).with(
        format(PugBot::WELCOME, "#channel")
      )
      send_message(@message, :join)
    end

    it "should cancel timeouts for tracked users" do
      set_test_message("JOIN #channel")
      user = @message.user
      user.track = true
      @plugin.timer_user_leave(user)
      send_message(@message, :join)
      expect(user.timer).to be_nil
    end
  end

  describe "left" do
    it "should start countdown for tracked users" do
      set_test_message("PART #channel")
      user = @message.user
      user.track = true
      send_message(@message, :leaving)
      expect(user.timer).to be_a(Cinch::Timer)
    end

    it "should announce that the user has 2 minutes to return" do
      set_test_message("PART #channel")
      user = @message.user
      user.track = true
      expect(@plugin.channel).to receive(:send).with(
        format(PugBot::DISCONNECTED, user.nick)
      )
      send_message(@message, :leaving)
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
      @queue2.add(@user1)
      @queue2.add(@user2)
      allow(user).to receive(:notice)
      send_message(@message)
      expect(user).to have_received(:notice).exactly(2).times
      msgs = [
        "TestQ2 (IN GAME) [0/2]",
        "Game 1 - Current players: test1 test2 - started 0 minutes ago."
      ]
      msgs.each { |msg| expect(user).to have_received(:notice).with(msg) }
    end

    it "should inform about multiple games underway" do
      set_test_message("PRIVMSG #channel :!status TestQ2")
      user = @message.user
      @queue2.add(@user1)
      @queue2.add(@user2)
      @queue2.add(@user3)
      @queue2.add(@user4)
      allow(user).to receive(:notice)
      send_message(@message)
      expect(user).to have_received(:notice).exactly(3).times
      msgs = [
        "TestQ2 (2 GAMES) [0/2]",
        "Game 1 - Current players: test1 test2 - started 0 minutes ago.",
        "Game 2 - Current players: test3 test4 - started 0 minutes ago."
      ]
      msgs.each { |msg| expect(user).to have_received(:notice).with(msg) }
    end

    it "should inform about a game just finished" do
      @queue2.add(@user1)
      @queue2.add(@user2)
      set_test_message("PRIVMSG #channel :!finish 2")
      send_message(@message)
      set_test_message("PRIVMSG #channel :!status TestQ2")
      user = @message.user
      allow(user).to receive(:notice)
      send_message(@message)
      expect(user).to have_received(:notice).exactly(2).times
      msgs = [
        "TestQ2 - [0/2]",
        "Game 1 - Just finished: test1 test2 - started 0 minutes ago."
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

    it "shouldn't start if there is a queue by that name already" do
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

    it "should join the queue we give as an argument" do
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

    it "should not join a queue if we are playing a game" do
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
      @queue2 = @plugin.queue_list.new_queue("TestQTwo")
    end

    it "shouldn't allow me to remove if I'm not opped" do
      set_test_message("PRIVMSG #channel :!remove Ben TestQ")
      expect(@message.user).to receive(:notice).with(PugBot::ACCESS_DENIED)
      send_message(@message)
    end

    it "should remove a user from all if supplied with no arguments" do
      @queue1.add(@user1)
      @queue2.add(@user1)
      set_test_message("PRIVMSG #channel :!remove test1")
      user = @message.user
      @message.channel.add_user(user, ["o"])
      expect(@message).to receive(:reply).with(
        format(PugBot::REMOVED, @user1.nick, "all queues", user.nick)
      )
      send_message(@message)
      expect(@queue1.users).to be_empty
      expect(@queue2.users).to be_empty
    end

    it "should remove a user from a specified queue" do
      @queue1.add(@user1)
      @queue2.add(@user1)
      set_test_message("PRIVMSG #channel :!remove test1 TestQTwo")
      user = @message.user
      @message.channel.add_user(user, ["o"])
      expect(@message).to receive(:reply).with(
        format(PugBot::REMOVED, @user1.nick, "TestQTwo", user.nick)
      )
      send_message(@message)
      expect(@queue1.users).to_not be_empty
      expect(@queue2.users).to be_empty
    end

    it "should let you know if they're not in the specified queue" do
      @queue2.add(@user1)
      set_test_message("PRIVMSG #channel :!remove test1 TestQ")
      user = @message.user
      @message.channel.add_user(user, ["o"])
      expect(@message.user).to receive(:notice).with(
        format(PugBot::NOT_IN_QUEUE, @user1.nick)
      )
      send_message(@message)
      expect(@queue1.users).to be_empty
      expect(@queue2.users).to_not be_empty
    end
  end

  describe "!end" do
    before(:each) do
      @queue1 = @plugin.queue_list.new_queue("TestQ", 2)
      @queue1.add(@user1)
      @queue1.add(@user2)
    end

    it "shouldn't allow non-ops to end queue" do
      set_test_message("PRIVMSG #channel :!end 1")
      expect(@message.user).to receive(:notice).with(PugBot::ACCESS_DENIED)
      send_message(@message)
    end

    it "should remove a specific queue" do
      set_test_message("PRIVMSG #channel :!end 1")
      user = @message.user
      @message.channel.add_user(user, ["o"])
      expect(@message).to receive(:reply).with(
        format(PugBot::ENDED, "TestQ", user.nick)
      )
      send_message(@message)
      expect(@plugin.queue_list.queues).to_not include(@queue1)
    end

    it "should reset all players to standby on ending a queue" do
      players = []
      @queue1.games.each { |game| players += game.users }
      players.flatten!
      set_test_message("PRIVMSG #channel :!end 1")
      user = @message.user
      @message.channel.add_user(user, ["o"])
      send_message(@message)
      expect(players).to all(satisfy { |player| player.status == :standby })
    end
  end

  describe "!finish" do
    before(:each) do
      @queue1 = @plugin.queue_list.new_queue("TestQ", 2)
    end

    it "should finish the only game in a specified queue" do
      @queue1.add(@user1)
      @queue1.add(@user2)
      set_test_message("PRIVMSG #channel :!finish 1")
      send_message(@message)
      expect(@queue1.games.first.status).to eq(:finished)
    end

    it "should finish the game one was playing without arguments" do
      set_test_message("PRIVMSG #channel :!finish")
      user = @message.user
      @queue1.add(@user1)
      @queue1.add(user)
      send_message(@message)
      expect(@queue1.games.first.status).to eq(:finished)
    end

    it "should not allow someone not playing to finish without arguments" do
      set_test_message("PRIVMSG #channel :!finish")
      user = @message.user
      @queue1.add(@user1)
      @queue1.add(@user2)
      expect(user).to receive(:notice).with(PugBot::FINISH_NOT_INGAME)
      send_message(@message)
      expect(@queue1.games.first.status).to_not eq(:finished)
    end

    it "should inform if there is more than one game in specified queue" do
      set_test_message("PRIVMSG #channel :!finish 1")
      user = @message.user
      @queue1.add(@user1)
      @queue1.add(@user2)
      @queue1.add(@user3)
      @queue1.add(@user4)
      expect(user).to receive(:notice).with(PugBot::FINISH_AMBIGUOUS_GAME)
      send_message(@message)
      expect(@queue1.games).to all(satisfy { |game| game.status == :ingame })
    end

    it "should finish the specified game in specified queue" do
      set_test_message("PRIVMSG #channel :!finish 1 2")
      @queue1.add(@user1)
      @queue1.add(@user2)
      @queue1.add(@user3)
      @queue1.add(@user4)
      send_message(@message)
      expect(@queue1.games.first.status).to eq(:ingame)
      expect(@queue1.games.last.status).to eq(:finished)
      expect(@queue1.games.first.users).to eq([@user1, @user2])
    end

    it "should set all players to finished when they finish" do
      @queue1.add(@user1)
      @queue1.add(@user2)
      players = []
      @queue1.games.each { |game| players += game.users }
      players.flatten!
      set_test_message("PRIVMSG #channel :!finish 1")
      send_message(@message)
      expect(players).to all(satisfy { |player| player.status == :finished })
    end

    it "should inform if there is no game for specified queue" do
      @queue1.add(@user1)
      set_test_message("PRIVMSG #channel :!finish 1")
      expect(@message.user).to receive(:notice).with(PugBot::NO_GAME)
      send_message(@message)
    end

    it "should start a countdown until the game is deleted" do
      @queue1.add(@user1)
      @queue1.add(@user2)
      game = @queue1.games.first
      set_test_message("PRIVMSG #channel :!finish 1")
      send_message(@message)
      expect(game.timer).to be_a(Cinch::Timer)
    end
  end

  describe "!sub" do
    before(:each) do
      @queue1 = @plugin.queue_list.new_queue("TestQ", 2)
      @queue2 = @plugin.queue_list.new_queue("TestQTwo", 2)
      @queue1.add(@user1)
      @queue1.add(@user2)
      @queue2.add(@user3)
    end

    it "should sub a playing user with one not playing" do
      set_test_message("PRIVMSG #channel :!sub test1 test3")
      expect(@message).to receive(:reply).with(
        format(PugBot::SUBBED, @user1.nick, @user3.nick, @message.user.nick)
      )
      send_message(@message)
      expect(@queue1.games[0].users).to_not include(@user1)
      expect(@queue1.games[0].users).to include(@user3)
    end

    it "should remove a sub from any queues they already in" do
      set_test_message("PRIVMSG #channel :!sub test1 test3")
      send_message(@message)
      expect(@queue2.users).to_not include(@user3)
    end

    it "should not allow someone already playing a game to sub" do
      @queue2.add(@user4)
      set_test_message("PRIVMSG #channel :!sub test3 test1")
      expect(@message.user).to receive(:notice).with(
        format(PugBot::ALREADY_PLAYING, "test1")
      )
      send_message(@message)
      expect(@queue2.games[0].users).to_not include(@user1)
      expect(@queue2.games[0].users).to include(@user3)
    end

    it "should inform if the player to replace is not in a game" do
      set_test_message("PRIVMSG #channel :!sub test4 test1")
      expect(@message.user).to receive(:notice).with(
        format(PugBot::NOT_PLAYING, "test4")
      )
      send_message(@message)
    end

    # it "should inform if either specified user can not be found" do
    #   puts "NOT FOUND"
    #   set_test_message("PRIVMSG #channel :!sub aesitonao test1")
    #   expect(@message.user).to receive(:notice).with(PugBot::USERS_NOT_FOUND)
    #   send_message(@message)
    #   set_test_message("PRIVMSG #channel :!sub test1 test5")
    #   expect(@message.user).to receive(:notice).with(PugBot::USERS_NOT_FOUND)
    #   send_message(@message)
    #   set_test_message("PRIVMSG #channel :!sub test6 test5")
    #   expect(@message.user).to receive(:notice).with(PugBot::USERS_NOT_FOUND)
    #   send_message(@message)
    # end
  end

  describe "!shutdown" do
    it "shouldn't allow non-ops to shutdown" do
      set_test_message("PRIVMSG #channel :!shutdown")
      expect(@message.user).to receive(:notice).with(PugBot::ACCESS_DENIED)
      send_message(@message)
    end

    it "should exit" do
      set_test_message("PRIVMSG #channel :!shutdown")
      user = @message.user
      @message.channel.add_user(user, ["o"])
      output = format(PugBot::KILLED, user.nick)
      expect(@plugin).to receive(:abort).with(output)
      expect(@message).to receive(:reply).with(output)
      send_message(@message)
    end
  end

  describe "!ts3" do
    it "should respond with ts3 info" do
      set_test_message("PRIVMSG #channel :!ts3")
      expect(@message).to receive(:reply).with(PugBot::TS3_INFO)
      send_message(@message)
    end
  end

  describe "!version" do
    it "should respond with version number" do
      set_test_message("PRIVMSG #channel :!version")
      expect(@message).to receive(:reply).with(
        format(PugBot::VERSION_REPLY, PugBot::VERSION)
      )
      send_message(@message)
    end
  end

  describe "!topic" do
    it "should become the new topic if there are no queues" do
      set_test_message("PRIVMSG #channel :!topic TEST TOPIC")
      user = @message.user
      @message.channel.add_user(user, ["o"])
      expect(@channel).to receive(:topic=).with("TEST TOPIC")
      send_message(@message)
    end

    it "should be appended to the topic if there are queues" do
      @plugin.queue_list.new_queue("TestQ")
      set_test_message("PRIVMSG #channel :!topic TEST TOPIC")
      @message.channel.add_user(@message.user, ["o"])
      expect(@channel).to receive(:topic=).with(
        "{ Queue 1: TestQ - [0/10] } - TEST TOPIC"
      )
      send_message(@message)
    end
  end

  describe "user_timeout" do
    it "should alert if the user is ingame" do
      set_test_message("PART #channel")
      user = @message.user
      user.status = :ingame
      user.track = true
      send_message(@message, :leaving)
      expect(@plugin.channel).to receive(:send).with(
        format(PugBot::DISCONNECTED_INGAME, user.nick, user.nick)
      )
      @plugin.instance_eval(&user.timer.block)
    end

    it "should remove from queues if the user is not ingame" do
      queue1 = @plugin.queue_list.new_queue("TestQ", 2)
      set_test_message("PART #channel")
      user = @message.user
      queue1.add(user)
      user.track = true
      send_message(@message, :leaving)
      expect(@plugin).to receive(:send).with(
        format(PugBot::DISCONNECTED_OUT, user.nick)
      )
      @plugin.instance_eval(&user.timer.block)
      expect(queue1.users).to_not include(user)
      expect(user.track).to be false
    end
  end

  describe "game_timeout" do
    before(:each) do
      @queue1 = @plugin.queue_list.new_queue("TestQ", 2)
      @queue1.add(@user1)
      @queue1.add(@user2)
      @game = @queue1.games.first
      set_test_message("PRIVMSG #channel :!finish 1")
    end

    it "should set all players to standby once they have counted down" do
      players = []
      @queue1.games.each { |game| players += game.users }
      players.flatten!
      send_message(@message)
      @plugin.instance_eval(&@game.timer.block)
      @game.timer.stop
      expect(players).to all(satisfy { |player| player.status == :standby })
    end

    it "should remove the game object" do
      send_message(@message)
      @plugin.instance_eval(&@game.timer.block)
      @game.timer.stop
      expect(@queue1.games).to be_empty
    end

    it "should enable other queues to check for waiters and add them" do
      @queue2 = @plugin.queue_list.new_queue("TestQ2", 2)
      send_message(@message)
      @queue2.add_wait(@user1)
      @plugin.instance_eval(&@game.timer.block)
      @game.timer.stop
      expect(@queue2.users).to include(@user1)
    end
  end

  describe "game_ready" do
    before(:each) do
      @queue1 = @plugin.queue_list.new_queue("TestQ", 2)
    end

    it "should create a new game when the correct number of people sign up" do
      @queue1.add(@user1)
      @queue1.add(@user2)
      expect(@queue1.games).to_not be_empty
    end

    it "should hilight all the players in the channel" do
      @queue1.add(@user1)
      expect(@plugin.channel).to receive(:send).with(
        "Game TestQ - starting for test1 test2"
      )
      @queue1.add(@user2)
    end

    it "should send an integrate event out" do
      @queue1.add(@user1)
      expect(@bot.handlers).to receive(:dispatch).with(
        :integrate,
        nil,
        :slack,
        any_args
      )
      @queue1.add(@user2)
    end
  end
end
