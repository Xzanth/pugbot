require "spec_helper"

describe PugBot::BotPlugin do
  before(:each) do
    @bot = TestBot.new
    @plugin = PugBot::BotPlugin.new(@bot)
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
