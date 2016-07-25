require "spec_helper"

describe PugBot::BotPlugin do
  before(:each) do
    @bot = TestBot.new
    @plugin = PugBot::BotPlugin.new(@bot)
  end

  describe "private message" do
    before(:each) do
      @plugin.setup
    end

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

  describe "!help" do
    before(:each) do
      set_test_message("PRIVMSG #midair.pug :!help")
    end

    it "should send back the help for using the pug bot" do
      expect(@message.user).to receive(:notice).with(PugBot::HELP)
      @plugin.help(@message)
    end
  end
end
