require 'cinch'
require 'cinch/plugins/identify'
require 'yaml'

class Game
	def initialize(arg=10)
		@max = arg
		@players = Array.new()
		@subs = Array.new()
	end

	def add(name)
		@players.push(name)
	end

	def add_sub(name)
		@subs.push(name)
	end

	def is_player(name)
		@players.include?(name)
	end

	def is_sub(name)
		@subs.include?(name)
	end

	def is_listed(name)
		self.is_player(name) or self.is_sub(name)
	end

	def is_full()
		if @players.length < @max
			false
		else
			true
		end
	end

	def remove(name)
		if self.is_player(name)
			@players.delete(name)
		elsif self.is_sub(name)
			@subs.delete(name)
		end
	end

	def update(m)
		m.channel.topic = self.to_s
		File.open('game.yml', 'w') {|f| f.write(YAML.dump(self)) }
	end

	def renew()
		@players = @subs.take(@max)
		@subs = @subs.drop(@max)
	end

	def list_subs()
		"#{@subs.join(' ')}"
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
			$game.update(m)
			m.user.notice "Please don't edit the topic if a game is in progress."
		end
	end

	on :channel, /^!help$/ do |m|
		m.user.notice "Supported commands are: !help, !status, !start, !add, !del, !subs. And for channel operators: !finish, !end and !remove."
	end

	on :channel, /^!status$/ do |m|
		if $game == {}
			m.user.notice "No game currently active."
		else
			m.user.notice "Players: #{$game}"
		end
	end

	on :channel, /^!start\s?(\d+)?$/ do |m, num|
		num = num.to_i
		if $game != {}
			m.user.notice "Game exists, please finish current game."
		elsif num == 0
			$game = Game.new()
			$game.update(m)
		elsif num.odd?
			m.user.notice "Game must have an even number of players."
		elsif num > 32
			m.user.notice "Games must have 32 or less players."
		# elsif num < 6
		# 	m.user.notice "Games must have at least 6 players."
		else
			$game = Game.new(num)
			$game.update(m)
		end
	end

	on :channel, /^!add$/ do |m|
		if $game == {}
			m.user.notice "No game currently active."
		elsif $game.is_listed(m.user.nick)
			m.user.notice "You've already signed up!"
		elsif $game.is_full()
			$game.add_sub(m.user.nick)
			$game.update(m)
			m.user.notice "This game is full, you have been added as a sub and will get priority next game."
		else
			$game.add(m.user.nick)
			$game.update(m)
		end
	end

	on :channel, /^!del$/ do |m|
		if $game == {}
			m.user.notice "No game currently active."
		elsif not $game.is_listed(m.user.nick)
			m.user.notice "You haven't signed up!"
		else
			$game.remove(m.user.nick)
			m.reply "#{m.user.nick} has abandoned us!"
			$game.update(m)
		end
	end

	on :channel, /^!remove (.+)$/ do |m, name|
		if not m.channel.opped?(m.user.nick)
			m.user.notice "Access denied - must be a channel operator."
		elsif $game == {}
			m.user.notice "No game currently active."
		elsif not $game.is_listed(name)
			m.user.notice "#{name} hasn't signed up!."
		else
			$game.remove(name)
			m.reply "#{name} has been removed by #{m.user.nick}."
			$game.update(m)
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
			$game.update(m)
		end
	end

	on :channel, /^!subs$/ do |m|
		if $game == {}
			m.user.notice "No game currently active."
		else
			m.user.notice "Subs: #{$game.list_subs}"
		end
	end


	on :join do |m|
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
end

bot.start
