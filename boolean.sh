#!/usr/bin/env bash

BASEDIR="$(cd $(dirname ${BASH_SOURCE[0]}) >/dev/null 2>&1 && pwd)"

API_VERSION_RAW_URL="https://raw.githubusercontent.com/shellscriptx/shellbot/master/ShellBot.sh"
API_GIT_URL="https://github.com/shellscriptx/shellbot.git"

_FALSE="⛔"
_TRUE="✅"

#======================== Comment one or another to see the diferrence ================
#_OPTIONS=(${_FALSE} ${_TRUE})
_OPTIONS=(OFF ON)
#======================================================================================

_COMMAND="${1:-test}"

exitOnError() {
  code=${2:-$?}
  if [[ $code -ne 0 ]]; then
      if [ ! -z "$1" ]; then echo -e "ERROR: $1" >&2 ; fi
      echo "Exiting..." >&2
      exit $code
  fi
}

helper.validate_vars() {
  local vars_list=($@)

  for v in $(echo ${vars_list[@]}); do
    export | grep ${v} > /dev/null
    result=$?
    if [[ ${result} -ne 0 ]]; then
      echo "Dependency of ${v} is missing"
      echo "Exiting..."
      exit -1
    fi
  done
}

helper.get_api() {
  local tmp_folder

  tmp_folder=$(mktemp -d)
  
  echo "[INFO] ShellBot API - Getting the newest version"
  git clone ${API_GIT_URL} ${tmp_folder} > /dev/null

  echo "[INFO] Providing the API for the bot's project folder"
  cp ${tmp_folder}/ShellBot.sh ${BASEDIR}/
  rm -fr ${tmp_folder}
}

helper.validate_vars TELEGRAM_TOKEN

if [[ ! -f ${BASEDIR}/ShellBot.sh ]]; then
	helper.get_api
	exitOnError "Error trying to get API (${API_GIT_URL})" $?
fi

init.button() {
	local button1 keyboard title
	title="*Switch:*"

	button1=''

	ShellBot.InlineKeyboardButton --button 'button1' \
		--text "${_OPTIONS[0]}" \
		--callback_data "tick_to_false" \
		--line 1
	
	keyboard="$(ShellBot.InlineKeyboardMarkup -b 'button1')"

	ShellBot.deleteMessage --chat_id ${message_chat_id[$id]} --message_id ${message_message_id[$id]}
	ShellBot.sendMessage --chat_id ${message_chat_id[$id]} \
				--text "$(echo -e ${title})" \
				--parse_mode markdown \
                --reply_markup "$keyboard"
}

tick_to_false.button() {
	local button2 keyboard2

	button2=''
	
	ShellBot.InlineKeyboardButton --button 'button2' \
		--text "${_OPTIONS[1]}" \
		--callback_data "tick_to_true" \
		--line 1

	keyboard2="$(ShellBot.InlineKeyboardMarkup -b 'button2')"

	ShellBot.answerCallbackQuery --callback_query_id ${callback_query_id[$id]} --text "making it true..."

    ShellBot.editMessageReplyMarkup --chat_id ${callback_query_message_chat_id[$id]} \
				--message_id ${callback_query_message_message_id[$id]} \
                            	--reply_markup "$keyboard2"
}

tick_to_true.button() {
    local button3 keyboard3

    button3=''

	ShellBot.InlineKeyboardButton --button 'button3' \
		--text "${_OPTIONS[0]}" \
		--callback_data "tick_to_false" \
		--line 1

    keyboard3="$(ShellBot.InlineKeyboardMarkup -b 'button3')"

    ShellBot.answerCallbackQuery --callback_query_id ${callback_query_id[$id]} --text "making it false..."

    ShellBot.editMessageReplyMarkup --chat_id ${callback_query_message_chat_id[$id]} \
                                --message_id ${callback_query_message_message_id[$id]} \
                                --reply_markup "$keyboard3"
}

source ${BASEDIR}/ShellBot.sh
ShellBot.init --token "${TELEGRAM_TOKEN}" --monitor --flush

while :
do
	ShellBot.getUpdates --limit 100 --offset $(ShellBot.OffsetNext) --timeout 30

	for id in $(ShellBot.ListUpdates)
	do
	(
		ShellBot.watchHandle --callback_data ${callback_query_data[$id]}

		if [[ ${message_entities_type[$id]} == bot_command ]]; then
			case ${message_text[$id]} in
				"/${_COMMAND}")
					init.button
					;;
			esac
		fi

		case ${callback_query_data[$id]} in
			"tick_to_true")
				tick_to_true.button
				;;
			"tick_to_false")
				tick_to_false.button
				;;
		esac

	) &
	done
done
