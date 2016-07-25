require "spec_helper"

describe PugBot::BotPlugin do
  before(:each) do
    @bot = TestBot.new
    @plugin = PugBot::BotPlugin.new(@bot)
    set_test_message("JOIN #channel", @bot.nick)
    @plugin.joined_channel(@message)
    @plugin.setup
  end

  describe "private message" do
    it "should respond first time with info" do
      set_test_message("PRIVMSG #{@bot.nick} :text")
      expect(@message).to receive(:reply).with(PugBot::I_AM_BOT)
      @plugin.private_message(@message)
    end

    it "should not respond to Q" do
      set_test_message("PRIVMSG #{@bot.nick} :text", "Q")
      expect(@message).not_to receive(:reply)
      @plugin.private_message(@message)
    end

    it "should not respond to same person twice" do
      set_test_message("PRIVMSG #{@bot.nick} :text")
      @plugin.private_message(@message)
      set_test_message("PRIVMSG #{@bot.nick} :text")
      expect(@message).not_to receive(:reply)
      @plugin.private_message(@message)
    end
  end

  describe "topic" do
    it "should not allow others to edit the topic" do
      set_test_message("TOPIC #channel :changed the topic")
      expect(@message.user).to receive(:notice).with(PugBot::EDIT_TOPIC)
      @plugin.topic_changed(@message)
    end

    it "should change the topic back after being edited" do
      # TODO
    end

    it "should allow the bot to edit the topic" do
      set_test_message("TOPIC #channel :changed the topic", @bot.nick)
      expect(@message.user).not_to receive(:notice)
      @plugin.topic_changed(@message)
    end
  end

  describe "!help" do
    before(:each) do
      set_test_message("PRIVMSG #channel :!help")
    end

    it "should send back the help for using the pug bot" do
      expect(@message.user).to receive(:notice).with(PugBot::HELP)
      @plugin.help(@message)
    end
  end
end
