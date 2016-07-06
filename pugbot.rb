require 'cinch'
require 'cinch/plugins/identify'
require 'yaml'

class Game
	def initialize(name, arg=10)
		@name = name
		@max = arg
		@players = Array.new()
		@subs = Array.new()
	end

	def add(user)
		@players.push(user)
		user.monitor()
	end

	def add_sub(user)
		@subs.push(user)
		user.monitor()
	end

	def is_player(user)
		@players.include?(user)
	end

	def is_sub(user)
		@subs.include?(user)
	end

	def is_listed(user)
		self.is_player(user) or self.is_sub(user)
	end

	def is_full()
		if @players.length < @max
			false
		else
			true
		end
	end

	def name()
		@name
	end

	def remove(user)
		if self.is_player(user)
			@players.delete(user)
			self.update()
			self.check_start()
		elsif self.is_sub(user)
			@subs.delete(user)
			self.update()
		else
			return false
		end
		user.unmonitor()
		return true
	end

	def update()
		free = @max - @players.length
		if !@subs.empty? and free > 0
			@subs.take(free).each { |a| @players.push(a) }
			@subs = @subs.drop(free)
		end
		#File.open('game.yml', 'w') {|f| f.write(YAML.dump(self)) }
	end

	def check_start()
		if (@max - @players.length) == 0
			@players.each { |a| a.send("The game you signed up for is full, join teamspeak.") }
			$channel.send("Game starting for: #{@players.join(' ')}")
		end
	end

	def renew()
		@players.each { |a| a.unmonitor() }
		@players = @subs.take(@max)
		@subs = @subs.drop(@max)
	end

	def list_subs()
		"#{@subs.join(' ')}"
	end

	def to_s()
		if @subs.empty?
			"#{@name} - [#{@players.length}/#{@max}]"
		else
			"#{@name} - [#{@players.length}/#{@max}] + #{@subs.length}"
		end
	end

	def long_s()
		if @players.empty?
			return "Game: #{@name} - [#{@players.length}/#{@max}]"
		elsif @subs.empty?
			return "Game: #{@name} - [#{@players.length}/#{@max}]: #{@players.join(' ')}"
		else
			return "Game: #{@name} - [#{@players.length}/#{@max}]: #{@players.join(' ')} - Subs: #{@subs.length}"
		end
	end

	def subs()
		if @subs.empty?
			return "No subs in #{@name} yet."
		else
			return "Game: #{@name} - Subs: #{@subs.join(' ')}."
		end
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
			$channel.send("#{self.nick} has not returned and has lost their space in the queue.")
			$games.each { |a| a.remove(self) }
			self.unmonitor()
		end
	end
end

$config = YAML::load_file(File.join(__dir__, 'config.yml'))
begin
	$game = YAML.load(File.read('game.yml'))
rescue Errno::ENOENT
	$games = Array.new()
	$channel = {}
end


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
		def set_topic
			topic = $games.map.with_index { |a, index| "{ Game #{index+1}: #{a} }"}
			puts topic
			$channel.topic = topic.join(' - ')
		end

		def default_game
			$games[0]
		end

		def find_game(aname)
			gamenames = Array.new()
			$games.each { |a| gamenames.push(a.name()) }
			if gamenames.include?(aname)
				return gamenames.index(aname)
			else
				return false
			end
		end

		def try_join(user, game)
			if game.is_listed(user)
				user.notice "You've already signed up!"
			elsif game.is_full()
				game.add_sub(user)
				game.update()
				user.notice "This game is full, you have been added as a sub and will get priority next game."
			else
				game.add(user)
				game.update()
				game.check_start()
			end
		end

		def try_leave(user, game)
			if not game.is_listed(user)
				user.notice "You haven't signed up!"
			else
				$channel.send "#{user.nick} has abandoned us!"
				game.remove(user)
			end
		end
	end

	on :topic do |m|
		if m.user.nick == bot.nick
			next
		elsif $games.empty?
			next
		else
			set_topic()
			m.user.notice "Please don't edit the topic if a game is in progress."
		end
	end

	on :channel, /^!help$/ do |m|
		m.user.notice "Supported commands are: !help, !status, !start, !add, !del, !subs. And for channel operators: !finish, !end and !remove."
	end

	on :channel, /^!status\s?(\d+|\w+)?$/ do |m, arg|
		if $games.empty?
			m.user.notice "No games currently active."
		elsif arg.nil?
			m.user.notice "#{default_game().long_s()}"
		elsif find_game(arg).is_a?(Integer)
			m.user.notice "#{$games[find_game(arg)].long_s()}"
		elsif arg =~ /^\d+$/ and $games[arg.to_i - 1]
			m.user.notice "#{$games[arg.to_i - 1].long_s()}"
		else
			m.user.notice "Game not found."
		end
	end

	on :channel, /^!start ([a-zA-Z]+)\s?(\d+)?$/ do |m, aname, num|
		num = num.to_i
		if find_game(aname)
			m.user.notice "A game with that name already exists."
		elsif num == 0
			game = Game.new(aname)
			$games.push(game)
			game.update()
			set_topic()
		elsif num.odd?
			m.user.notice "Game must have an even number of players."
		elsif num > 32
			m.user.notice "Games must have 32 or less players."
		#elsif num < 6
		#	m.user.notice "Games must have at least 6 players."
		else
			game = Game.new(aname, num)
			$games.push(game)
			game.update()
			set_topic()
		end
	end

	on :channel, /^!add\s?(\d+|\w+)?$/ do |m, arg|
		if $games.empty?
			m.user.notice "No games currently active."
		elsif arg.nil?
			try_join(m.user, default_game())
		elsif find_game(arg).is_a?(Integer)
			try_join(m.user, $games[find_game(arg)])
		elsif arg =~ /^\d+$/ and $games[arg.to_i - 1]
			try_join(m.user, $games[arg.to_i - 1])
		else
			m.user.notice "Game not found."
		end
		set_topic()
	end

	on :channel, /^!del\s?(\d+|\w+)?$/ do |m, arg|
		if $games.empty?
			m.user.notice "No games currently active."
		elsif arg.nil?
			$channel.send "#{m.user.nick} has abandoned us!"
			$games.each { |a| a.remove(m.user) }
		elsif find_game(arg).is_a?(Integer)
			try_leave(m.user, $games[find_game(arg)])
		elsif arg =~ /^\d+$/ and $games[arg.to_i - 1]
			try_leave(m.user, $games[arg.to_i - 1])
		else
			m.user.notice "Game not found."
		end
		set_topic()
	end

	#on :channel, /^!remove (.+)$/ do |m, name|
	#	if not m.channel.opped?(m.user.nick)
	#		m.user.notice "Access denied - must be a channel operator."
	#	elsif $game == {}
	#		m.user.notice "No game currently active."
	#	elsif not $game.is_listed(User(name))
	#		m.user.notice "#{name} hasn't signed up!."
	#	else
	#		m.reply "#{name} has been removed by #{m.user.nick}."
	#		$game.remove(User(name))
	#	end
	#end

	on :channel, /^!end\s?(\d+|\w+)?$/ do |m, arg|
		if not m.channel.opped?(m.user.nick)
			m.user.notice "Access denied - must be a channel operator."
		elsif $games.empty?
			m.user.notice "No games currently active."
		elsif arg.nil?
			m.reply "Games ended by #{m.user.nick}."
			$games = Array.new()
		elsif find_game(arg).is_a?(Integer)
			m.reply "#{$games[find_game(arg)].name()} ended by #{m.user.nick}."
			$games.delete_at(find_game(arg))
		elsif arg =~ /^\d+$/ and $games[arg.to_i - 1]
			m.reply "#{$games[arg.to_i - 1].name()} ended by #{m.user.nick}."
			$games.delete_at(arg.to_i - 1)
		else
			m.user.notice "Game not found."
		end
		set_topic()
	end

	on :channel, /^!finish\s?(\d+|\w+)?$/ do |m, arg|
		if not m.channel.opped?(m.user.nick)
			m.user.notice "Access denied - must be a channel operator."
		elsif $games.empty?
			m.user.notice "No games currently active."
		elsif arg.nil?
			default_game().renew()
			default_game().update()
		elsif find_game(arg).is_a?(Integer)
			$games[find_game(arg)].renew()
			$games[find_game(arg)].update()
		elsif arg =~ /^\d+$/ and $games[arg.to_i - 1]
			$games[arg.to_i - 1].renew()
			$games[arg.to_i - 1].update()
		else
			m.user.notice "Game not found."
		end
		set_topic()
	end

	on :channel, /^!subs\s?(\d+|\w+)?$/ do |m, arg|
		if $games.empty?
			m.user.notice "No games currently active."
		elsif arg.nil?
			m.user.notice "#{default_game().subs()}"
		elsif find_game(arg).is_a?(Integer)
			m.user.notice "#{$games[find_game(arg)].subs()}"
		elsif arg =~ /^\d+$/ and $games[arg.to_i - 1]
			m.user.notice "#{$games[arg.to_i - 1].subs()}"
		else
			m.user.notice "Game not found."
		end
	end

	on :private do |m|
		if not m.user.nick == "Q"
			m.reply "I am a bot, please direct all questions/comments to Xzanth"
		end
	end

	on :join do |m|
		if m.user.monitored?
			m.user.stop_countdown()
		end

		if m.user.nick == bot.nick
			$channel = m.channel
		elsif $games.empty?
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

bot.start
