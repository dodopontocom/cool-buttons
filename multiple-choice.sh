#!/usr/bin/env bash

BASEDIR="$(cd $(dirname ${BASH_SOURCE[0]}) >/dev/null 2>&1 && pwd)"

API_GIT_URL="https://github.com/shellscriptx/shellbot.git"

_UNTICKED="◻"
_TICKED="☑"

_OPTIONS=(jpg png svg pdf jpeg)

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
        local button1 keyboard title count
        title="*Pick Multiple Options:*"
        count=1

        button1=''

        for i in $(echo ${_OPTIONS[@]}); do
                ShellBot.InlineKeyboardButton --button 'button1' --text "${_UNTICKED} ${i}" --callback_data "tick_${i}" --line ${count}
                count=$((count+1))
        done

        keyboard="$(ShellBot.InlineKeyboardMarkup -b 'button1')"

        ShellBot.deleteMessage --chat_id ${message_chat_id[$id]} --message_id ${message_message_id[$id]}
        ShellBot.sendMessage --chat_id ${message_chat_id[$id]} \
                                --text "$(echo -e ${title})" \
                                --parse_mode markdown \
                                --reply_markup "$keyboard"
}

tick.button() {
        local button2 keyboard2 count arr
        count=1

        arr=($(echo ${callback_query_message_reply_markup_inline_keyboard_callback_data} | tr '|' ' '))
        for ((i=0; i < ${#arr[@]}; i++)); do
                echo "button callback data: ${arr[$i]}" | grep "^tick_"
        done

        button2=''

        for ((i=0; i < ${#arr[@]}; i++)); do
                if [[ "${callback_query_data[$id]}" == "${arr[$i]}" ]]; then
                        ShellBot.InlineKeyboardButton --button 'button2' --text "${_TICKED} ${arr[$i]##*_}" --callback_data "untick_${arr[$i]##*_}" --line ${count}
                elif [[ "${arr[$i]}" =~ ^tick_ ]]; then
                        ShellBot.InlineKeyboardButton --button 'button2' --text "${_UNTICKED} ${arr[$i]##*_}" --callback_data "tick_${arr[$i]##*_}" --line ${count}
                else
                        ShellBot.InlineKeyboardButton --button 'button2' --text "${_TICKED} ${arr[$i]##*_}" --callback_data "untick_${arr[$i]##*_}" --line ${count}
                fi
                count=$((count+1))
        done

        keyboard2="$(ShellBot.InlineKeyboardMarkup -b 'button2')"

        ShellBot.answerCallbackQuery --callback_query_id ${callback_query_id[$id]} --text "ticking ${callback_query_data[$id]}..."

        ShellBot.editMessageReplyMarkup --chat_id ${callback_query_message_chat_id[$id]} \
                                --message_id ${callback_query_message_message_id[$id]} \
                                --reply_markup "$keyboard2"
}

untick.button() {
        local button3 keyboard3 count arr
        count=1

        arr=($(echo ${callback_query_message_reply_markup_inline_keyboard_callback_data} | tr '|' ' '))
        for ((i=0; i < ${#arr[@]}; i++)); do
                echo "button callback data: ${arr[$i]}"
        done

        button3=''

        for ((i=0; i < ${#arr[@]}; i++)); do
                if [[ "${callback_query_data[$id]}" == "${arr[$i]}" ]]; then
                        ShellBot.InlineKeyboardButton --button 'button3' --text "${_UNTICKED} ${arr[$i]##*_}" --callback_data "tick_${arr[$i]##*_}" --line ${count}
                elif [[ "${arr[$i]}" =~ ^untick_ ]]; then
                        ShellBot.InlineKeyboardButton --button 'button3' --text "${_TICKED} ${arr[$i]##*_}" --callback_data "untick_${arr[$i]##*_}" --line ${count}
                else
                        ShellBot.InlineKeyboardButton --button 'button3' --text "${_UNTICKED} ${arr[$i]##*_}" --callback_data "tick_${arr[$i]##*_}" --line ${count}
                fi
                count=$((count+1))
        done

        keyboard3="$(ShellBot.InlineKeyboardMarkup -b 'button3')"

        ShellBot.answerCallbackQuery --callback_query_id ${callback_query_id[$id]} --text "unticking..."

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

                for i in $(echo ${_OPTIONS[@]}); do
                        case ${callback_query_data[$id]} in
                                "tick_${i%%/*}")
                                        tick.button
                                        ;;
                                "untick_${i%%/*}")
                                        untick.button
                                        ;;
                        esac
                done

        ) &
        done
done
