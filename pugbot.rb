require 'cinch'
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

	def is_player(name)
		@players.include?(name)
	end

	def is_full()
		if @players.length < @max
			false
		else
			true
		end
	end

	def remove(name)
		@players.delete(name)
	end

	def update(m)
		m.channel.topic = self.to_s
	end

	def to_s()
		"[#{@players.length}/#{@max}]: #{@players.join(' ')}"
	end
end

$game = {}

bot = Cinch::Bot.new do
	configure do |c|
		config = YAML::load_file(File.join(__dir__, 'config.yml'))
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

	on :message, /^!help$/ do |m|
		m.user.notice "Supported commands are: !help, !status, !start, !add, !del. And for channel operators: !finish and !remove."
	end

	on :message, /^!status$/ do |m|
		if $game == {}
			m.user.notice "No game currently active."
		else
			m.user.notice "Players: #{$game}"
		end
	end

	on :message, /^!start\s?(\d+)?$/ do |m, num|
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
		elsif num < 6
			m.user.notice "Games must have at least 6 players."
		else
			$game = Game.new(num)
			$game.update(m)
		end
	end

	on :message, /^!add$/ do |m|
		if $game == {}
			m.user.notice "No game currently active."
		elsif $game.is_full()
			m.user.notice "This game is full, try again later!"
		elsif $game.is_player(m.user.nick)
			m.user.notice "You've already signed up!"
		else
			$game.add(m.user.nick)
			$game.update(m)
		end
	end

	on :message, /^!del$/ do |m|
		if $game == {}
			m.user.notice "No game currently active."
		elsif not $game.is_player(m.user.nick)
			m.user.notice "You haven't signed up!"
		else
			$game.remove(m.user.nick)
			m.reply "#{m.user.nick} has abandoned us!"
			$game.update(m)
		end
	end

	on :message, /^!remove (.+)$/ do |m, name|
		if not m.channel.opped?(m.user.nick)
			m.user.notice "Access denied - must be a channel operator."
		elsif $game == {}
			m.user.notice "No game currently active."
		elsif not $game.is_player(name)
			m.user.notice "#{name} hasn't signed up!."
		else
			$game.remove(name)
			m.reply "#{name} has been removed by #{m.user.nick}."
			$game.update(m)
		end
	end

	on :message, /^!finish$/ do |m|
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

	on :join do |m|
		if m.user.nick == bot.nick
			next
		elsif $game == {}
			m.user.notice "Welcome to #{m.channel} - no games are currently active type !start to begin signups."
		elsif $game.is_full()
			m.user.notice "Welcome to #{m.channel} - the next game is currently full, wait for a new game to be started and use !add to sign up."
		else
			m.user.notice "Welcome to #{m.channel} - signups for the next game are currently in progress, just type !add to sign up."
		end
	end
end

bot.start
