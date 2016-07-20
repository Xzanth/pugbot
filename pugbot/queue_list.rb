# This class holds all the queues currently in session as an array and performs
# actions regarding locating, creating, deleting queues as well as handling
# a queue being default and any other methods that are related to all queues.
class QueueList
	# @return [Array<Queue>] The queues currently in this queue list
	attr_reader :queues

	# @return [Queue] The default queue
	attr_reader :default

	def initialize
		@queues = Array.new
		@default = nil
	end

	# Create a new queue, make it the default if it is the only queue.
	# @param [String] name The name for this specific queue
	# @param [Integer] max The max number of players in this queue
	def new_queue(name, max=10)
		queue = Queue.new(name, max)
		if @queues.empty?
			@default = queue
		end
		@queues.push(queue)
	end

	# Remove a queue, if it is the default make the first queue on the list
	# default.
	# @param [Queue] queue The queue to remove
	def remove_queue(queue)
		if @default == queue
			@default = @queues[0]
			# [TODO]: what if this is last queue or we delete
			# queues[0]
		end
		@queues.delete(queue)
	end

	# Find a queue by its name.
	# @param [String] name The name of the queue you want to be returned
	# @return [Queue] The queue with the specified name if it exists
	def find_queue_by_name(name)
		queuenames = Array.new
		@queues.each { |queue| queuenames.push(queue.name) }
		if queuenames.include?(name)
			return @queues[queuenames.index(name)]
		else
			return nil
		end
	end

	# Find the queue a specific user is playing.
	# @param [Cinch::User] user The user we want to know about
	# @return [Queue] The queue the specified user is playing in
	def find_queue_playing(user)
		@queues.select { |queue| queue.in_queue.include?(user) }[0]
	end

	# Remove a user from all queues they are in.
	# @param [Cinch::User] user The user we want to remove from all queues
	def remove_from_queues(user)
		@queues.each { |queue| queue.remove(user) }
	end

	# Find if a user is either playing in a queue or signed up to a queue.
	# @param [Cinch::User] user The user we want to know about
	# @return [Boolean] Whether they are playing/queued or not
	def is_player_active(user)
		@queues.any? do |queue|
			queue.listed?(user) or queue.listed_wait?(user)
		end
	end

	# Removed method find_queue_by_index

	# Find a queue by a string argument, either a number referring to index
	# or a string referring to the name of the queue, or return the default
	# queue if the string is empty.
	# @param [String] arg Either empty, an index of queues or a queue name
	# @return [Queue] The queue that is specified by arg
	def find_queue_by_arg(arg)
		if arg.nil?
			@default
		elsif arg =~ /^\d+$/
			@queues[arg.to_i - 1]
		elsif arg =~ /^\w+$/
			self.find_queue_by_name(arg)
		else
			nil
		end
	end

	# Set the default queue to a specified queue.
	# @param [Queue] queue The queue to become the new default queue.
	def set_default(queue)
		@default = queue
	end

	# Set the channel topic to a list of the queues in the queuelist nicely
	# formatteda.
	# @return [String] The nicely formatted list
	def set_topic
		# [TODO]: globals ugh
		topic = @queues.map.with_index do |queue, index|
			"{ Game #{index+1}: #{queue} }"
		end
		$channel.topic = topic.join(' - ')
	end
end
