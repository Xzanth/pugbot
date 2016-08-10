module PugBot
  ACCESS_DENIED = "Access denied - must be a channel operator.".freeze
  USERS_NOT_FOUND = "One or more users not found.".freeze
  NOT_PLAYING = "%s is not playing a game.".freeze
  ALREADY_PLAYING = "%s is already playing a game.".freeze
  QUEUE_NOT_FOUND = "Queue not found.".freeze
  NOT_IN_QUEUE = "%s is not in this queue.".freeze
  YOU_NOT_IN_QUEUE = "You are not in this queue.".freeze
  NOT_IN_ANY_QUEUES = "%s is not in any queues.".freeze
  YOU_NOT_IN_ANY_QUEUES = "You are not in any queues.".freeze
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
  " one 30s after the last ended.".freeze
  NAME_TAKEN = "A queue with that name already exists.".freeze
  ODD_NUMBER = "Games must have an even number of players.".freeze
  TOO_LARGE = "Games must have 32 or less players.".freeze
  HELP = "Supported commands are: !help, !status (all|gamename|num), !finish"\
  " (gamename|num), !add (all|gamename|num), !del (all|gamename|num), !subs"\
  " and !sub (name1) (name2). And for channel operators: !start gamename"\
  " (num), !end (gamename|num) and !remove name.".freeze
  EDIT_TOPIC = "Please don't edit the topic.".freeze
  I_AM_BOT = "I am a bot please direct all questions/comments to"\
  " Xzanth.".freeze
  WELCOME = "Welcome to %s - sign up for games by typing '!add"\
  " nameofgame' and remove yourself from queues with '!del'.".freeze
end
