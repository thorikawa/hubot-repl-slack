# Description
#   An example hubot bot using Repl-AI powered by NTT docomo https://repl-ai.jp/
#
# Configuration:
#   HUBOT_REPL_API_KEY: required, REPL API key
#   HUBOT_REPL_BOT_ID: required, REPL Bot ID
#   HUBOT_REPL_TOPIC_ID: required, REPL Topic ID
#
# Author:
#   Takahiro Poly Horikawa <horikawa.takahiro@gmail.com>

request = require 'request'
moment = require 'moment'

REPL_API_KEY = process.env.HUBOT_REPL_API_KEY
REPL_BOT_ID = process.env.HUBOT_REPL_BOT_ID
REPL_TOPIC_ID = process.env.HUBOT_REPL_TOPIC_ID

REGISTRATION_URL = 'https://api.repl-ai.jp/v1/registration'
DIALOGUE_URL = 'https://api.repl-ai.jp/v1/dialogue'


class ReplEngine

  constructor: (@robot) ->
    @replUserIdMap = {}
    @initTalkingFlagMap = {}

  now: () ->
    moment().format("YYYY-MM-DD HH:mm:ss")

  getReplUserId: (userName, callback) ->
    if userName of @replUserIdMap
      callback null, @replUserIdMap[userName]
      return

    body =
      botId: REPL_BOT_ID
    options =
      url: REGISTRATION_URL
      method: 'POST'
      headers:
        'x-api-key': REPL_API_KEY
      json: body

    request options, (err, res, json) =>
      @robot.logger.debug "docomo registration API response", err, json
      if err?
        callback err
        return
      if json.error?
        callback json.error
        return
      userId = json.appUserId
      @replUserIdMap[userName] = userId
      callback err, userId

  dialogue: (replUserId, input, callback) ->
    if replUserId of @initTalkingFlagMap
      initTalkingFlag = false
    else
      initTalkingFlag = true
      @initTalkingFlagMap[replUserId] = 1

    body =
      appUserId: replUserId
      botId: REPL_BOT_ID
      voiceText: input
      initTalkingFlag: initTalkingFlag
      initTopicId: REPL_TOPIC_ID
      appRecvTime: @now()
      appSendTime: @now()
    options =
      url: DIALOGUE_URL
      method: 'POST'
      headers:
        'x-api-key': REPL_API_KEY
      json: body
    request options, (err, res, json) =>
      @robot.logger.debug "docomo dialogue API response", err, json
      if err?
        callback err
        return
      if json.error?
        callback json.error
        return
      output = json.systemText.expression
      callback err, output

module.exports = (robot) ->
  REMOVE_REG_EXP = new RegExp("@?#{robot.name}:?\\s*", "g")
  replEngine = new ReplEngine robot

  robot.respond /(\S+)/i, (msg) ->
    name = msg.message.user.name
    message = msg.message.text
    message = message.replace(REMOVE_REG_EXP, "")

    robot.logger.info "received '#{message}' from @#{name}"
    
    replEngine.getReplUserId name, (err, replUserId) ->
      if err?
        robot.logger.error "registration failed #{err}"
        msg.send "registration failed #{err}"
        return

      replEngine.dialogue replUserId, message, (err, output) ->
        if err?
          robot.logger.error "dialogue failed #{err}"
          msg.send "dialogue failed #{err}"
        else
          msg.send output
