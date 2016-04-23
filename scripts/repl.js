'use strict';

const request = require('request'),
      moment = require("moment");
const REPL_API_KEY = process.env.REPL_API_KEY;
const REPL_BOT_ID = process.env.REPL_BOT_ID;
const REPL_TOPIC_ID = process.env.REPL_TOPIC_ID;

const REGISTRATION_URL = 'https://api.repl-ai.jp/v1/registration';
const DIALOGUE_URL = 'https://api.repl-ai.jp/v1/dialogue';

let replUserIdMap = {};
let recvTimeMap = {};
let initTalkingFlagMap = {};

function register(callback) {
	let body = {
		botId: REPL_BOT_ID
	};
	let options = {
		url: REGISTRATION_URL,
		method: 'POST',
		headers: {
			'x-api-key': REPL_API_KEY
		},
		json: body
	};
	request(options, (err, res, json) => {
		console.log(err, json);
		if (err) {
			callback(err);
			return;
		}
		if (json.error) {
			callback(json.error);
			return;
		}
		let userId = json.appUserId;
		callback(err, userId);
	});
}

function now() {
	return moment().format("YYYY-MM-DD HH:mm:ss");
}

function dialogue(replUserId, input, callback) {
	let initTalkingFlag;
	
	if (replUserId in initTalkingFlagMap) {
		initTalkingFlag = false;
	} else {
		initTalkingFlag = true;
		initTalkingFlagMap[replUserId] = 1;
	}
	

	let body = {
		appUserId: replUserId,
		botId: REPL_BOT_ID,
		voiceText: input,
		initTalkingFlag: initTalkingFlag,
		initTopicId: REPL_TOPIC_ID,
		appRecvTime: now(),
		appSendTime: now()
	};
	let options = {
		url: DIALOGUE_URL,
		method: 'POST',
		headers: {
			'x-api-key': REPL_API_KEY
		},
		json: body
	};
	request(options, (err, res, json) => {
		console.log(err, json);
		if (err) {
			callback(err);
			return;
		}
		if (json.error) {
			callback(json.error);
			return;
		}
		let output = json.systemText.expression;
		callback(err, output);
	});
}

module.exports = (robot) => {
	robot.respond(/(\S+)/i, function(msg) {
		let name = msg.message.user.name;
		let message = msg.message.text;
		message = message.replace(/\@[a-zA-Z\.\-\_;:\<\>]+/g, '')
		console.log(`received "${message}" from @$name`);
		if (name in replUserIdMap) {
			dialogue(replUserIdMap[name], message, (err, output) => {
				if (err) {
					msg.send(`error: ${err}`);
				} else {
					msg.send(output);
				}
			});
		} else {
			register((err, replUserId) => {
				replUserIdMap[name] = replUserId;
				dialogue(replUserIdMap[name], message, (err, output) => {
					if (err) {
						msg.send(`error: ${err}`);
					} else {
						msg.send(output);
					}
				});
			});
		}
	});
};
