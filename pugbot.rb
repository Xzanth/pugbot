require 'cinch'
require 'cinch/plugins/identify'
require 'slack-ruby-client'
require 'timers'
require 'yaml'

class GameList
	def initialize()
		@games = Array.new()
		@default = nil
	end

	def new_game(name, max=10)
		game = Game.new(name, max)
		if @games.empty?
			@default = game
		end
		@games.push(game)
	end

	def remove_game(game)
		if @default == game
			@default = @games[0]
		end
		@games.delete(game)
	end

	def games
		@games
	end

	def find_game_by_name(name)
		gamenames = Array.new()
		@games.each { |game| gamenames.push(game.name()) }
		if gamenames.include?(name)
			return @games[gamenames.index(name)]
		else
			return nil
		end
	end

	def find_game_playing(user)
		@games.select { |game| game.in_game.include?(user) }[0]
	end

	def is_player_active(user)
		@games.any? { |game| game.in_game.include?(user) or game.listed?(user) }
	end

	def find_game_by_index(i)
		@games[i]
	end

	def find_game_by_arg(arg)
		if arg.nil?
			self.default_game()
		elsif arg =~ /^\d+$/
			self.find_game_by_index(arg.to_i - 1)
		elsif arg =~ /^\w+$/
			self.find_game_by_name(arg)
		else
			nil
		end
	end

	def set_default(game)
		@default = game
	end

	def default_game
		@default
	end

	def set_topic
		topic = $gamelist.games().map.with_index { |game, index| "{ Game #{index+1}: #{game} }"}
		$channel.topic = topic.join(' - ')
	end
end

class Game
	def initialize(name, max)
		@name = name
		@max = max
		@users = Array.new()
		@ingame = Array.new()
		@finished = Array.new()
		@queue = Array.new()
		@status = :standby
	end

	def players
		@users.take(@max)
	end

	def available_players
		@users.select { |user| user.get_status == :standby }.take(@max)
	end

	def subs
		@users.drop(@max)
	end

	def in_game
		@ingame
	end

	def listed?(user)
		@users.include?(user)
	end

	def in_game?(user)
		@ingame.include?(user)
	end

	def add(user)
		@users.push(user)
		user.monitor()
	end

	def queue(user)
		@queue.push(user)
	end

	def remove(user)
		@users.delete(user)
		if not $gamelist.is_player_active(user)
			user.unmonitor()
		end
	end

	def sub(user, sub)
		@ingame.delete(user)
		@ingame.push(sub)
	end

	def name
		@name
	end

	def status
		@status
	end

	def ready
		avail = self.available_players()
		if avail.length() >= @max and @status == :standby
			@status = :ingame
			@ingame = avail
			@ingame.each { |user| user.set_status(:ingame) }
			@ingame.each { |user| self.remove(user) }
			@ingame.each { |user| $gamelist.games().each { |game| game.remove(user) } }
			$channel.send("Game #{@name} - starting for #{@ingame.join(' ')}")
			$client.web_client.chat_postMessage(channel: '#pugs', text: "Game #{@name} - starting for #{@ingame.join(' ')} - sign up for the next on <http://webchat.quakenet.org/?channels=midair.pug|#midair.pug>", as_user: true)
			update_slack_topic
			return true
		elsif @users.length() >= @max and @status == :standby
			$channel.send("Game #{@name} - ready to start waiting on players to finish game.}")
			return false
		end
	end

	def finish
		if @status == :ingame
			@finished = @ingame
			@finished.each { |player| player.set_status(:finished) }
			@ingame = Array.new()
			@status = :standby
		end
	end

	def start_countdown(timer)
		@countdown = timer
	end

	def stop_countdown()
		if @countdown.is_a?(Cinch::Timer)
			@countdown.stop()
		end
	end

	def countdown_end()
		@finished.each { |user| user.set_status(:standby) }
		@finished = Array.new()
		$gamelist.games().each { |game| game.check_queue() }
	end

	def check_queue()
		work = @queue.select { |user| user.get_status == :standby }
		if work.length() > 0
			work = work.shuffle()
			work.each { |user| self.add(user) }
			@queue = @queue - work
			$channel.send("Users have been randomized into queue")
			self.ready()
			$gamelist.set_topic()
		end
	end

	def print_short()
		if @status == :ingame
			"#{@name} - IN GAME - [#{self.players.length}/#{@max}] + #{self.subs.length}"
		else
			"#{@name} - [#{self.players.length}/#{@max}] + #{self.subs.length}"
		end
	end

	def print_long()
		if @status == :ingame
			"Game: #{@name} - IN GAME - [#{self.players.length}/#{@max}]: #{self.players.join(' ')} - Subs: #{self.subs.length}"
		else
			"Game: #{@name} - [#{self.players.length}/#{@max}]: #{self.players.join(' ')} - Subs: #{self.subs.length}"
		end
	end

	def print_ingame()
		"#{@name} - Current players: #{@ingame.join(' ')}"
	end

	def print_subs()
		if self.subs.empty?
			"No subs in #{@name} yet"
		else
			"Game: #{@name} - Subs #{@subs.join(' ')}"
		end
	end

	def to_s()
		self.print_short()
	end
end

module Cinch
	class User
		def start_countdown(timer)
			@countdown = timer
		end

		def stop_countdown()
			if @countdown.is_a?(Cinch::Timer)
				@countdown.stop()
			end
		end

		def countdown_end()
			if self.get_status() == :ingame
				$channel.send("#{self.nick} has disconnected but is in game. Please use '!sub #{self.nick} new_player' to replace them if needed.")
				$gamelist.games.each { |game| game.remove(self) }
			else
				$channel.send("#{self.nick} has not returned and has lost their space in the queue.")
				$gamelist.games.each { |game| game.remove(self) }
				if not $gamelist.is_player_active(user)
					user.unmonitor()
				end
			end
		end

		def get_status
			if @status == :ingame
				return :ingame
			elsif @status == :finished
				return :finished
			else
				return :standby
			end
		end

		def set_status(arg)
			@status = arg
		end
	end
end

$config = YAML::load_file(File.join(__dir__, 'config.yml'))
begin
	$game = YAML.load(File.read('game.yml'))
rescue Errno::ENOENT
	$gamelist = GameList.new()
	$channel = {}
	$names = []
end
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
	end

	helpers do
		def try_join(user, game)
			if game.listed?(user)
				user.notice "You've already signed up!"
			elsif game.in_game?(user)
				user.notice "You are currently in this game"
			elsif user.get_status == :ingame
				user.notice "You are currently in a game, please wait for it to finish before joining another"
			elsif user.get_status == :finished
				user.notice "You have just finished a game, and are in the queue to join this one"
				game.queue(user)
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


	on :private do |m|
		if not $names.include?(m.user.nick)
			m.reply "I am a bot, please direct all questions/comments to Xzanth"
			$names.push(m.user.nick)
		end
	end

	on :join do |m|
		if m.user.monitored?
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
		if m.user.monitored?
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
$timers.now_and_every(60) { update_slack_topic }
threads = []
threads << Thread.new { $client.start! }
threads << Thread.new { bot.start }
threads << Thread.new { loop { $timers.wait } }
threads.each { |thr| thr.join }
