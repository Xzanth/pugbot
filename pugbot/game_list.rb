# This class holds all the games currently in session as an array and performs
# actions regarding locating, creating, deleting games as well as handling
# a game being default and any other methods that are related to all games.
class GameList
	# @return [Array<Game>] The games currently in this game list
	attr_reader :games

	# @return [Game] The default game
	attr_reader :default

	def initialize()
		@games = Array.new()
		@default = nil
	end

	# Create a new game, make it the default if it is the only game.
	# @param [String] name The name for this specific game
	# @param [Integer] max The max number of players in this game
	def new_game(name, max=10)
		game = Game.new(name, max)
		if @games.empty?
			@default = game
		end
		@games.push(game)
	end

	# Remove a game, if it is the default make the first game on the list
	# default.
	# @param [Game] game The game to remove
	def remove_game(game)
		if @default == game
			@default = @games[0]
			# [TODO]: what if this is last game or we delete
			# games[0]
		end
		@games.delete(game)
	end

	# Find a game by its name.
	# @param [String] name The name of the game you want to be returned
	# @return [Game] The game with the specified name if it exists
	def find_game_by_name(name)
		gamenames = Array.new()
		@games.each { |game| gamenames.push(game.name()) }
		if gamenames.include?(name)
			return @games[gamenames.index(name)]
		else
			return nil
		end
	end

	# Find the game a specific user is playing.
	# @param [Cinch::User] user The user we want to know about
	# @return [Game] The game the specified user is playing in
	def find_game_playing(user)
		@games.select { |game| game.in_game.include?(user) }[0]
	end

	# Find if a user is either playing in a game or signed up to a queue.
	# @param [Cinch::User] user The user we want to know about
	# @return [Boolean] Whether they are playing/queued or not
	def is_player_active(user)
		@games.any? do |game|
			game.in_game.include?(user) or game.listed?(user)
		end
	end

	# Removed method find_game_by_index

	# Find a game by a string argument, either a number referring to index
	# or a string referring to the name of the game, or return the default
	# game if the string is empty.
	# @param [String] arg Either empty, an index of games or a game name
	# @return [Game] The game that is specified by arg
	def find_game_by_arg(arg)
		if arg.nil?
			self.default_game()
		elsif arg =~ /^\d+$/
			@games[arg.to_i - 1]
		elsif arg =~ /^\w+$/
			self.find_game_by_name(arg)
		else
			nil
		end
	end

	# Set the default game to a specified game.
	# @param [Game] game The game to become the new default game.
	def set_default(game)
		@default = game
	end

	# Set the channel topic to a list of the games in the gamelist nicely
	# formatteda.
	# @return [String] The nicely formatted list
	def set_topic
		# [TODO]: globals ugh
		topic = $gamelist.games().map.with_index do |game, index|
			"{ Game #{index+1}: #{game} }"
		end
		$channel.topic = topic.join(' - ')
	end
end
