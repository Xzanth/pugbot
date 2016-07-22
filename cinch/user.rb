module Cinch
  # Extending Cinch's user class to add the ability to track whether they are
  # ingame, finished or not using @status, and to handle removing them from
  # queues and other things via @track
  class User
    # @return [Symbol] The status of the user in regards to games
    # and queues. Can either be :standby :ingame or :finished
    attr_accessor :status

    # @return [Boolean] Whether we should track when this user leaves
    # and rejoins the irc channel
    attr_accessor :track

    # To be called whenever the user leaves the pug channel, if
    # they are being tracked start a countdown until #timeout is
    # called
    # @see #timeout
    def left
      return unless @track
      @countdown = $timers.after(120) { timeout }
    end

    # To be called whenever the user rejoins the pug channel, if
    # they are being tracked, cancel the current countdown.
    def rejoined
      return unless @track
      @countdown.cancel
    end

    # To be called when the timeout runs out, if the user is still
    # being tracked, remove them from queues or if they are in game
    # then alert that they might need to be subbed.
    def timeout
      return unless @track
      if @status == :ingame
        $channel.send "#{@nick} has disconnected but is in game. Please use "\
        "'!sub #{@nick} new_player' to replace them if needed."
      else
        $channel.send "#{@nick} has not returned and has lost their space in "\
        "the queue."
        $queue_list.remove_from_queues(self)
        @track = false
        $queue_list.set_topic
      end
    end
  end
end
