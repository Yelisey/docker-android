#!/bin/bash

set -e

# Логи
function write_log() {
  echo "{ \"type\": \"$1\", \"value\": \"$2\" }"
}

# Пишем о состояниях симулятора в лог.
function update_state() {
  write_log "state-update" "$1"
}

<<COMMENT Полное отключение любой анимации
function disable_animation() {
  adb shell "settings put global window_animation_scale 0.0"
  adb shell "settings put global transition_animation_scale 0.0"
  adb shell "settings put global animator_duration_scale 0.0"
  echo "...Disable animations"
};
COMMENT

# Ставим ru-RU локаль
function set_locale() {
  adb shell "su 0 setprop persist.sys.locale ru-RU"
  adb shell "su 0 setprop ctl.restart zygote"
  echo "...Set locale"
};

# политики Android
function hidden_policy() {
  adb shell "settings put global hidden_api_policy_pre_p_apps 1;settings put global hidden_api_policy_p_apps 1;settings put global hidden_api_policy 1"
  echo "...Hidden policy"
};


# Ждать, пока Android закрузится
function wait_for_boot() {
  update_state "ANDROID_BOOTING"

  # Ждать загрузки adb
  while [ -n "$(adb wait-for-device > /dev/null)" ]; do
    adb wait-for-device
    sleep 1
  done

  # Ждать пока эмулятора не загрузится
  COMPLETED=$(adb shell getprop sys.boot_completed | tr -d '\r')
  while [ "$COMPLETED" != "1" ]; do
    COMPLETED=$(adb shell getprop sys.boot_completed | tr -d '\r')
    sleep 5
  done
  sleep 1
  if [ "$DISABLE_ANIMATION" = "true" ]; then
  disable_animation
  sleep 1
  fi

  if [ "$DISABLE_HIDDEN_POLICY" = "true" ]; then
  hidden_policy
  sleep 1
  fi

  set_locale
  sleep 5

  update_state "ANDROID_READY"
}
