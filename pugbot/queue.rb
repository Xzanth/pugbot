# This class is an object for each queue for each gametype that contains the
# players, the list of games related to that queue and all associated features.
class Queue
	# @return [String] The name of the queue
	attr_reader :name

	def intialize(name, max)
		@name = name
		@max = max
		@users = Array.new
		@wait = Array.new
		@games = Array.new
	end

	# Join a queue, by testing if we can and then either adding,
	# add_waiting. Returns the status of the function so that the user can
	# be notified.
	# @param [Cinch::User] user The user to try joining with
	# @return [Symbol] The status of our attempt to join
	def join(user)
		if self.listed?(user)
			return :already_queued
		elsif self.ingame?(user)
			return :already_playing
		elsif self.listed_wait?(user)
			return :already_waiting
		elsif user.status == :ingame
			return :ingame
		elsif user.status == :finished
			self.add_wait(user)
			return :added_wait
		else
			self.add(user)
			self.ready
			return :added
		end
	end

	# Leave a queue, by testing if we can then removing ourselves.
	# @param [Cinch::User] user The user to try joining with
	# @return [Symbol] The status of our attempt to leave
	def leave(user)
		if self.ingame?(user)
			return :already_playing
		elsif not self.listed?(user)
			return :not_queued
		else
			self.remove(user)
			return :removed
		end
	end


	# Test if a user is in this queue.
	# @param [Cinch::User] user The user to test for
	# @return [Boolean] Whether they are in the queue or not
	def listed?(user)
		@users.include?(user)
	end

	# Add a user to this queue and start tracking them.
	# @param [Cinch::User] user The user to add
	def add(user)
		@users.push(user)
		user.track = true
	end

	# Test if a user is in the wait queue.
	# @param [Cinch::User] user The user to test for
	# @return [Boolean] Whether they are in the wait queue or not
	def listed_wait?(user)
		@wait.include?(user)
	end

	# Test if a user is in any game being played in this queue.
	# @return [Boolean] Whether they are in a game or not
	def ingame?(user)
		@games.any { |game| game.users.include?(user) }
	end

	# Add a user to the wait queue.
	# @param [Cinch::User] user The user to add
	def add_wait(user)
		@wait.push(user)
		user.track = true
	end

	# Remove a user from either normal or waiting queue and stop tracking
	# them if they are not doing anything else.
	# @param [Cinch::User] user The user to remove
	def remove(user)
		@users.delete(user)
		@wait.delete(user)
		if not $gamelist.is_player_active(user)
			user.track = false
		end
	end

	# Remove a game that has finished
	# @param [Game] game The game that can be removed
	def finish(game)
		@games.delete(game)
	end

	# Check if enough people are signed up to start a game and if they are
	# then start one, alerting the relevant channels.
	def ready
		if users >= @max
			ingame = users.take(@max)
			game = Game.new(ingame)
			@games.push(game)
			@users = @users - ingame
			ingame.each do |user|
				user.status = :ingame
				$gamelist.remove_from_queues(user)
			end
			text = "Game #{@name} - starting for #{ingame.join(' ')}"
			$channel.send(text)
			$slack_client.web_client.chat_postMessage(
				channel: '#pugs',
				text: "#{text} - sign up for the next on <http://webchat.quakenet.org/?channels=midair.pug|#midair.pug>",
				as_user: true
			)
		end
	end

	# Check the users waiting in @wait and see if any have become able to be
	# added, if they have randomize them into queue.
	def check_waiters
		finished = @wait.select { |user| user.status == :standby }
		if finished.length > 0
			finished.shuffle!
			@users += finished
			@wait -= finished
			$channel.send("Users have been randomized into queue")
			self.ready
			$gamelist.set_topic
		end
	end

	# Just print the queue name, whether there is one in progress or not
	# (and the number if there are multiple) and the number of players and subs.
	# @return [String] The status of this queue
	def print_short
		text = "#{@name} - "
		if @games.length == 1
			text += "IN GAME - "
		elsif @games.length > 1
			text += "#{@games.length} GAMES - "
		end
		text += "[#{@users.length}/#{@max}]"
		return text
	end

	# Prints the same as print_short just with a list of all the queued
	# users as well.
	# @return [String] The status of this queue and list of queued users
	def print_long
		text = self.print_short
		text += ": #{@users.join(' ')}"
		return text
	end

	# Print all the games currently being played, with a list of all the
	# players in each
	# @return [String] The formatted list of all games with players
	def print_ingame
		if @games.length == 1
			return "#{@name} - " + @games[0].to_s
		elsif @games.length > 1
			text = ""
			@games.each.with_index do |game, index|
				text += "#{@name} #{index + 1} - #{@game.to_s}\n"
			end
			return text
		else
			return ""
		end
	end

	# Default to print_short for printing the queue object.
	# @return [String] The status of this queue
	# @see #print_short
	def to_s
		self.print_short
	end
end
