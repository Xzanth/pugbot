require 'cinch'
require 'cinch/plugins/identify'
require 'yaml'

class Game
	def initialize(channel, arg=10)
		@max = arg
		@players = Array.new()
		@subs = Array.new()
		@channel = channel
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

	def remove(user)
		if self.is_player(user)
			@players.delete(user)
			$game.update()
			self.check_start()
		elsif self.is_sub(user)
			@subs.delete(user)
			$game.update()
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
		@channel.topic = self.to_s
		#File.open('game.yml', 'w') {|f| f.write(YAML.dump(self)) }
	end

	def check_start()
		if (@max - @players.length) == 0
			@players.each { |a| a.send("The game you signed up for is full, join teamspeak.") }
			@channel.send("Game starting for: #{@players.join(' ')}")
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

	def get_channel()
		@channel
	end

	def to_s()
		if @players.empty?
			return "[#{@players.length}/#{@max}]"
		elsif @subs.empty?
			return "[#{@players.length}/#{@max}]: #{@players.join(' ')}"
		else
			return "[#{@players.length}/#{@max}]: #{@players.join(' ')} - Subs: #{@subs.length}"
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
			$game.get_channel().send("#{self.nick} has not returned and has lost their space in the queue.")
			$game.remove(self)
			self.unmonitor()
		end
	end
end

begin
	$game = YAML.load(File.read('game.yml'))
rescue Errno::ENOENT
	$game = {}
end


bot = Cinch::Bot.new do
	configure do |c|
		config = YAML::load_file(File.join(__dir__, 'config.yml'))
		c.plugins.plugins = [Cinch::Plugins::Identify]
		c.plugins.options[Cinch::Plugins::Identify] = {
			:username => config['username'],
			:password => config['password'],
			:type     => config['auth'],
		}
		c.nick = config['nick']
		c.server = config['server']
		c.channels = config['channels']
		c.local_host = config['local_host']
	end

	on :topic do |m|
		if m.user.nick == bot.nick
			next
		elsif $game == {}
			next
		else
			$game.update()
			m.user.notice "Please don't edit the topic if a game is in progress."
		end
	end

	on :channel, /^!help$/ do |m|
		m.user.notice "Supported commands are: !help, !status, !start, !add, !del, !subs. And for channel operators: !finish, !end and !remove."
	end

	on :channel, /^!status$/ do |m|
		if $game == {}
			m.reply "No game currently active."
		else
			m.reply "Players: #{$game}"
		end
	end

	on :channel, /^!start\s?(\d+)?$/ do |m, num|
		num = num.to_i
		if $game != {}
			m.user.notice "Game exists, please finish current game."
		elsif num == 0
			$game = Game.new(m.channel)
			$game.update()
		elsif num.odd?
			m.user.notice "Game must have an even number of players."
		elsif num > 32
			m.user.notice "Games must have 32 or less players."
		elsif num < 6
			m.user.notice "Games must have at least 6 players."
		else
			$game = Game.new(m.channel, num)
			$game.update()
		end
	end

	on :channel, /^!add$/ do |m|
		if $game == {}
			m.user.notice "No game currently active."
		elsif $game.is_listed(m.user.nick)
			m.user.notice "You've already signed up!"
		elsif $game.is_full()
			$game.add_sub(m.user)
			$game.update()
			m.user.notice "This game is full, you have been added as a sub and will get priority next game."
		else
			$game.add(m.user)
			$game.update()
			$game.check_start()
		end
	end

	on :channel, /^!del$/ do |m|
		if $game == {}
			m.user.notice "No game currently active."
		elsif not $game.is_listed(m.user)
			m.user.notice "You haven't signed up!"
		else
			m.reply "#{m.user.nick} has abandoned us!"
			$game.remove(m.user)
		end
	end

	on :channel, /^!remove (.+)$/ do |m, name|
		if not m.channel.opped?(m.user.nick)
			m.user.notice "Access denied - must be a channel operator."
		elsif $game == {}
			m.user.notice "No game currently active."
		elsif not $game.is_listed(User(name))
			m.user.notice "#{name} hasn't signed up!."
		else
			m.reply "#{name} has been removed by #{m.user.nick}."
			$game.remove(User(name))
		end
	end

	on :channel, /^!end$/ do |m|
		if not m.channel.opped?(m.user.nick)
			m.user.notice "Access denied - must be a channel operator."
		elsif $game == {}
			m.user.notice "No game currently active."
		else
			$game = {}
			m.reply "Game ended by #{m.user.nick}."
			m.channel.topic = ""
		end
	end

	on :channel, /^!finish$/ do |m|
		if not m.channel.opped?(m.user.nick)
			m.user.notice "Access denied - must be a channel operator."
		elsif $game == {}
			m.user.notice "No game currently active."
		else
			$game.renew
			$game.update()
		end
	end

	on :channel, /^!subs$/ do |m|
		if $game == {}
			m.user.notice "No game currently active."
		else
			m.reply "Subs: #{$game.list_subs}"
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
			next
		elsif $game == {}
			m.user.notice "Welcome to #{m.channel} - no games are currently active type !start to begin signups."
		elsif $game.is_full()
			m.user.notice "Welcome to #{m.channel} - the next game is currently full, type !add to register as a sub and get in queue for the next game."
		else
			m.user.notice "Welcome to #{m.channel} - signups for the next game are currently in progress, just type !add to sign up."
		end
	end

	on :leaving do |m, user|
		if m.user.monitored?
			user.start_countdown(Timer(120, {shots: 1}) { user.countdown_end() })
			$game.get_channel.send("#{user.nick} has disconnected and has 2 mins to return before losing their space.")
		end
	end
end

bot.start
