# Extend the cinch module
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

    # @return [Cinch::Timer] The timer that counts down after a user leaves
    # a channel
    attr_accessor :timer

    # To be called whenever the user rejoins the pug channel, if
    # they are being tracked, cancel the current countdown.
    def rejoined
      return unless @track
      @timer.stop
    end

    def account
      account = PugBot::Storage::User.first(auth: authname) if authed?
      account = PugBot::Storage::User.first(nick: nick,
                                            authed: false) unless authed?
      return make_account if account.nil?
      account
    end

    def make_account
      account = PugBot::Storage::User.create(authed: true,
                                             auth:   authname,
                                             nick:   authname) if authed?
      account = PugBot::Storage::User.create(authed: false,
                                             nick:   nick) unless authed?
      account
    end
  end
end
