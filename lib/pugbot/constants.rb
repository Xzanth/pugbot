module PugBot
  WELCOME = "Welcome to %s - sign up for games by typing '!add"\
  " nameofgame' and remove yourself from queues with '!del'. Type '!help' to"\
  " get a list of possible commands.".freeze
  ACCESS_DENIED = "Access denied - must be a channel operator.".freeze
  USERS_NOT_FOUND = "One or more users not found.".freeze
  NOT_PLAYING = "%s is not playing a game.".freeze
  ALREADY_PLAYING = "%s is already playing a game.".freeze
  QUEUE_NOT_FOUND = "Queue not found.".freeze
  NOT_IN_QUEUE = "%s is not in this queue.".freeze
  YOU_NOT_IN_QUEUE = "You are not in this queue.".freeze
  NOT_IN_ANY_QUEUES = "%s is not in any queues.".freeze
  YOU_NOT_IN_ANY_QUEUES = "You are not in any queues.".freeze
  NO_GAME = "No game found for this queue.".freeze
  REMOVED = "%s has been removed from %s by %s.".freeze
  SUBBED = "%s has been subbed with %s by %s.".freeze
  ENDED = "%s has been ended by %s".freeze
  LEFT = "%s has abandoned %s.".freeze
  LEFT_ALL = "%s has abandoned all queues.".freeze
  YOU_ARE_PLAYING = "Cannot perform this action while you are playing a"\
  " game.".freeze
  ALREADY_IN_QUEUE = "You are already in this queue.".freeze
  ALREADY_IN_ALL_QUEUES = "You are already in all queues.".freeze
  FINISHED_IN_QUEUE = "You have just finished a game and will be added to this"\
  " one 90s after the last ended.".freeze
  FINISH_NOT_INGAME = "You are not in a game and must specify the game to be"\
  " finished.".freeze
  FINISH_AMBIGUOUS_GAME = "There is more than one game in the specified queue"\
  " please specify the game as well.".freeze
  NAME_TAKEN = "A queue with that name already exists.".freeze
  ODD_NUMBER = "Games must have an even number of players.".freeze
  TOO_LARGE = "Games must have 32 or less players.".freeze
  EDIT_TOPIC = "Please don't edit the topic.".freeze
  I_AM_BOT = "I am a bot please direct all questions/comments to"\
  " Xzanth.".freeze
  KILLED = "Bot shut down by %s!".freeze
  RESTARTED = "Bot effectively restarted by %s!".freeze
  DISCONNECTED = "%s has disconnected and has 2 mins to return before losing"\
  " their space in queue.".freeze
  DISCONNECTED_INGAME = "%s has disconnected but is in game. Please use '!sub"\
  " %s new_player' to replace them if needed.".freeze
  DISCONNECTED_OUT = "%s has not returned and has lost their space in the"\
    " queue.".freeze
  TS3_INFO = "ts3.playmidair.com".freeze
  VERSION_REPLY = "Currently running pugbot version: %s".freeze

  FINISH_TIMEOUT = 90
  LEAVE_TIMEOUT = 120

  SLACK_GAME_START = "Game of %s - starting for %s - sign up for the next on"\
  " %s".freeze
end
