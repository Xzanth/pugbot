require 'cinch'
require 'cinch/plugins/identify'
require 'slack-ruby-client'
require 'timers'
require 'yaml'

require_relative 'pugbot/queue_list'
require_relative 'pugbot/queue'
require_relative 'pugbot/game'

$config = YAML::load_file(File.join(__dir__, 'config.yml'))
$gamelist = QueueList.new()
$channel = {}
$names = []
$timers = Timers::Group.new

bot = Cinch::Bot.new do
	configure do |c|
		c.plugins.plugins = [Cinch::Plugins::Identify]
		c.plugins.options[Cinch::Plugins::Identify] = {
			:username => $config['username'],
			:password => $config['password'],
			:type     => $config['auth'],
		}
		c.nick = $config['nick']
		c.realname = $config['realname']
		c.user = $config['user']
		c.server = $config['server']
		c.channels = $config['channels']
		c.local_host = $config['local_host']
		c.messages_per_second = 0.7
		c.server_queue_size = 10
	end

	helpers do
		def try_join(user, queue)
			if queue.listed?(user)
				user.notice "You've already signed up!"
			elsif queue.in_game?(user)
				user.notice "You are currently in this game"
			elsif user.status == :ingame
				user.notice "You are currently in a game, please wait for it to finish before joining another"
			elsif user.status == :finished
				if game.queued?(user)
					user.notice "You are already in queue to join the next"
				else
					user.notice "You have just finished a game, and are in the queue to join this one"
					game.queue(user)
				end
			else
				game.add(user)
				game.ready()
			end
		end

		def try_leave(user, game)
			if game.in_game?(user)
				user.notice "You are currently in game please find a replacement and use '!sub #{user.nick} sub_name'"
			elsif not game.listed?(user)
				user.notice "You haven't signed up!"
			else
				$channel.send "#{user.nick} has abandoned #{game.name()}"
				game.remove(user)
			end
		end

		def try_remove(admin, user, game)
			if game.in_game?(user)
				admin.notice "#{user.nick} is in a game please find a replacement and use !sub"
			elsif game.listed?(user)
				$channel.send "#{user.nick} has been remove from #{game.name()} by #{admin.nick}"
				game.remove(user)
			end
		end
	end

	on :topic do |m|
		if m.user.nick == bot.nick
			next
		elsif $gamelist.games().empty?
			next
		else
			$gamelist.set_topic()
			m.user.notice "Please don't edit the topic if a game is in progress."
		end
	end

	on :channel, /^!help$/ do |m|
		m.user.notice "Supported commands are: !help, !status (all|gamename|num), !finish (gamename|num), !add (all|gamename|num), !del (all|gamename|num), !subs and !sub (name1) (name2). And for channel operators: !start gamename (num), !end (gamename|num) and !remove name."
	end

	on :channel, /^!status\s?(\d+|\w+)?$/ do |m, arg|
		if $gamelist.games().empty?
			m.user.notice "No games currently active."
		elsif arg == "all"
			$gamelist.games().each { |game| m.user.notice game.print_long() }
		elsif $gamelist.find_game_by_arg(arg).nil?
			m.user.notice "Game not found."
		else
			game = $gamelist.find_game_by_arg(arg)
			m.user.notice game.print_long()
			if game.status() == :ingame
				m.user.notice game.print_ingame()
			end
		end
	end

	on :channel, /^!start ([a-zA-Z]+)\s?(\d+)?$/ do |m, name, num|
		num = num.to_i
		if not m.channel.opped?(m.user.nick)
			m.user.notice "Access denied - must be a channel operator."
		elsif $gamelist.find_game_by_name(name)
			m.user.notice "A game with that name already exists."
		elsif num == 0
			$gamelist.new_game(name)
			$gamelist.set_topic()
		elsif num.odd?
			m.user.notice "Game must have an even number of players."
		elsif num > 32
			m.user.notice "Games must have 32 or less players."
		#elsif num < 6
		#	m.user.notice "Games must have at least 6 players."
		else
			$gamelist.new_game(name, num)
			$gamelist.set_topic()
		end
	end

	on :channel, /^!add\s?(\d+|\w+)?$/ do |m, arg|
		if $gamelist.games().empty?
			m.user.notice "No games currently active."
		elsif arg == "all"
			$gamelist.games().each { |game| try_join(m.user, game) }
		elsif $gamelist.find_game_by_arg(arg).nil?
			m.user.notice "Game not found."
		else
			try_join(m.user, $gamelist.find_game_by_arg(arg))
		end
		$gamelist.set_topic()
	end

	on :channel, /^!del\s?(\d+|\w+)?$/ do |m, arg|
		if $gamelist.games().empty?
			m.user.notice "No games currently active."
		elsif arg.nil? or arg == "all"
			$gamelist.games().each { |game| try_leave(m.user, game) }
		elsif $gamelist.find_game_by_arg(arg).nil?
			m.user.notice "Game not found."
		else
			try_leave(m.user, $gamelist.find_game_by_arg(arg))
		end
		$gamelist.set_topic()
	end

	on :channel, /^!remove (.+)\s?(\d+|\w+)?$/ do |m, name, arg|
		if not m.channel.opped?(m.user.nick)
			m.user.notice "Access denied - must be a channel operator."
		elsif $gamelist.games().empty?
			m.user.notice "No games currently active."
		elsif arg.nil?
			$gamelist.games().each { |game| try_remove(m.user, User(name), game) }
		elsif $gamelist.find_game_by_arg(arg).nil?
			m.user.notice "Game not found."
		else
			try_remove(m.user, User(name), $gamelist.find_game_by_arg(arg))
		end
		$gamelist.set_topic()
	end

	on :channel, /^!end\s?(\d+|\w+)?$/ do |m, arg|
		if not m.channel.opped?(m.user.nick)
			m.user.notice "Access denied - must be a channel operator."
		elsif $gamelist.games().empty?
			m.user.notice "No games currently active."
		elsif $gamelist.find_game_by_arg(arg).nil?
			m.user.notice "Game not found."
		else
			game = $gamelist.find_game_by_arg(arg)
			game.in_game().each { |user| user.set_status(:standby) }
			$gamelist.remove_game(game)
		end
		$gamelist.set_topic()
	end

	on :channel, /^!finish\s?(\d+|\w+)?$/ do |m, arg|
		if $gamelist.games().empty?
			m.user.notice "No games currently active."
		elsif $gamelist.find_game_by_arg(arg).nil?
			m.user.notice "Game not found."
		else
			game = $gamelist.find_game_by_arg(arg)
			if game.status == :ingame
				game.start_countdown(Timer(30, {shots: 1}) { game.countdown_end() })
				game.finish()
				$gamelist.games().each { |g| g.ready() }
			end
		end
		$gamelist.set_topic()
	end

	on :channel, /^!subs\s?(\d+|\w+)?$/ do |m, arg|
		if $gamelist.games().empty?
			m.user.notice "No games currently active."
		elsif $gamelist.find_game_by_arg(arg).nil?
			m.user.notice "Game not found."
		else
			m.user.notice $gamelist.find_game_by_arg(arg).print_subs()
		end
	end

	on :channel, /^!sub (.+) (.+)$/ do |m, user, sub|
		if User(user).nil? or User(sub).nil?
			m.user.notice "Couldn't find one of the users you mentioned"
		elsif $gamelist.find_game_playing(User(user)).nil?
			m.user.notice "#{user} is not playing a game"
		elsif not $gamelist.find_game_playing(User(sub)).nil?
			m.user.notice "#{sub} is already playing a game"
		else
			User(sub).set_status(:ingame)
			User(user).set_status(:standby)
			$gamelist.find_game_playing(User(user)).sub(User(user), User(sub))
			$gamelist.games().each { |game| game.remove(User(sub)) }
			$channel.send "#{user} has been subbed with #{sub} by #{m.user.nick}"
			$gamelist.set_topic()
		end
	end

	on :channel, /^!giveup$/ do |m|
		if m.channel.opped?(m.user.nick)
			m.user.notice "Access denied - must be a channel operator."
		else
			abort("Program killed by admin")
		end
	end

	on :private do |m|
		if not $names.include?(m.user.nick)
			m.reply "I am a bot, please direct all questions/comments to Xzanth"
			$names.push(m.user.nick)
		end
	end

	on :join do |m|
		if m.user.check_leave?
			m.user.stop_countdown()
		end

		if m.user.nick == bot.nick
			$channel = m.channel
		elsif $gamelist.games().empty?
			m.user.notice "Welcome to #{m.channel} - no games are currently active type '!start name (numberofplayers)' to start a game"
		else
			m.user.notice "Welcome to #{m.channel} - sign up for games by typing '!add nameofgame' and remove yourself from signups with '!del'"
		end
	end

	on :leaving do |m, user|
		if m.user.check_leave?
			user.start_countdown(Timer(120, {shots: 1}) { user.countdown_end() })
			$channel.send("#{user.nick} has disconnected and has 2 mins to return before losing their space.")
		end
	end
end

bot.loggers << Cinch::Logger::FormattedLogger.new(File.open("log.log", "a"))

Slack.configure do |config|
	config.token = $config['slack_api']
end

$client = Slack::RealTime::Client.new

$client.on :message do |data|
	case data['text']
	when /^!status$/ then
		$gamelist.games().each do |game|
			$client.message channel: data['channel'], text: "#{game.print_long}"
			if game.status() == :ingame
				$client.message channel: data['channel'], text: "#{game.print_ingame}"
			end
		end
	when /^!/ then
		$client.web_client.chat_postMessage(channel: '#pugs', text: 'Please join <http://webchat.quakenet.org/?channels=midair.pug|#midair.pug> on quakenet to interact fully with the pug bot', as_user: true)
	end
end

def update_slack_topic
	old = $client.web_client.channels_info(channel: '#pugs')
	topic = $gamelist.games().map.with_index { |game, index| "{ Game #{index+1}: #{game} }"}
	topic = topic.join(' - ')
	if topic != old.channel.topic.value
		$client.web_client.channels_setTopic(channel: '#pugs', topic: "#{topic}")
	end
end
#$timers.now_and_every(300) { update_slack_topic }
threads = []
threads << Thread.new { $client.start! }
threads << Thread.new { bot.start }
threads << Thread.new { loop { $timers.wait } }
threads.each { |thr| thr.join }
