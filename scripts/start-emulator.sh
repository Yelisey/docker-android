#!/bin/bash

set -e

source ./emulator-monitoring.sh

# The emulator console port.
EMULATOR_CONSOLE_PORT=5554
# The ADB port used to connect to ADB.
ADB_PORT=5555
OPT_MEMORY=${MEMORY:-6144}
OPT_CORES=${CORES:-4}
OPT_SKIP_AUTH=${SKIP_AUTH:-true}
API_VERSION=31
AUTH_FLAG=
# Start ADB server by listening on all interfaces.
echo "Starting the ADB server ..."
adb -a -P 5037 server nodaemon &

# Detect ip and forward ADB ports from the container's network
# interface to localhost.
LOCAL_IP=$(ip addr list eth0 | grep "inet " | cut -d' ' -f6 | cut -d/ -f1)
socat tcp-listen:"$EMULATOR_CONSOLE_PORT",bind="$LOCAL_IP",fork tcp:127.0.0.1:"$EMULATOR_CONSOLE_PORT" &
socat tcp-listen:"$ADB_PORT",bind="$LOCAL_IP",fork tcp:127.0.0.1:"$ADB_PORT" &

export USER=root

# Creating the Android Virtual Emulator.
AVD_NAME="android"
AVD_CONFIG_FILE="/data/${AVD_NAME}.avd/config.ini"
TEST_AVD=$(avdmanager list avd | grep -c "$AVD_NAME.avd" || true)

if [ "$TEST_AVD" == "1" ]; then
  echo "Use the exists Android Virtual Emulator ..."
else
  echo "Creating the Android Virtual Emulator ..."
  echo "Using package '$PACKAGE_PATH', ABI '$ABI' and device '$DEVICE_ID' for creating the emulator"
  echo no | avdmanager create avd \
    --force \
    --name "$AVD_NAME" \
    --abi "$ABI" \
    --package "$PACKAGE_PATH" \
    --device "$DEVICE_ID"

  # !!! ЗАМЕНА СЕКЦИИ: Создание минималистичного config.ini
  echo "Creating minimal, high-performance config.ini..."

  # Создаем необходимый путь к файлу
  mkdir -p "$(dirname "$AVD_CONFIG_FILE")"

  # Записываем оптимизированный config.ini
  cat > "$AVD_CONFIG_FILE" <<- EOL
PlayStore.enabled = false
abi.type = x86_64
avd.ini.encoding = UTF-8
# -- РЕСУРСЫ --
hw.cpu.arch = x86_64
hw.cpu.ncore = ${OPT_CORES} # Используем переменную CORES (по умолчанию 4)
hw.ramSize = ${OPT_MEMORY} # Используем переменную MEMORY (по умолчанию 6144)
# -- ДИСПЛЕЙ (1080p) --
hw.lcd.density = 320
hw.lcd.width = 1080
hw.lcd.height = 1920
# -- МЕДИА И СЕНСОРЫ (Отключено для CI) --
hw.audioInput = no
hw.audioOutput = no
hw.accelerometer = no
hw.gyroscope = no
hw.dPad = no
hw.mainKeys = yes
hw.keyboard = no
hw.sensors.proximity = no
hw.sensors.magnetic_field = no
hw.sensors.orientation = no
hw.sensors.temperature = no
hw.sensors.light = no
hw.sensors.pressure = no
hw.sensors.humidity = no
hw.sensors.magnetic_field_uncalibrated = no
hw.sensors.gyroscope_uncalibrated = no
# -- СИСТЕМНЫЕ ПАРАМЕТРЫ --
image.sysdir.1 = system-images/android-${API_VERSION}/google_apis/x86_64/
tag.display = Google APIs
tag.id = google_apis
skin.dynamic = yes
skin.name=1080x1920
EOL

  echo "...Minimal config.ini created successfully."
fi
<<COMMENT
## 🚀 Добавление `advancedFeatures.ini` (Новый Раздел). Раскомментировать тогда, когда собираешь контейнер c API33 и выше

ADVANCED_FEATURES_FILE="/root/.android/advancedFeatures.ini"

echo "Creating advanced features file: ${ADVANCED_FEATURES_FILE}..."

# Создаем директорию, если она не существует
mkdir -p "$(dirname "$ADVANCED_FEATURES_FILE")"

# Создаем или перезаписываем advancedFeatures.ini с нужными настройками
cat > "$ADVANCED_FEATURES_FILE" <<- EOL
# Отключение Vulkan для предотвращения сбоев, связанных с ним
Vulkan = off
# Включение прямого доступа к GL-памяти для оптимизации
GLDirectMem = on
EOL

echo "...Advanced features configured successfully."
COMMENT


if [ "$OPT_SKIP_AUTH" == "true" ]; then
  AUTH_FLAG="-skip-adb-auth"
fi

# If GPU acceleration is enabled, we create a virtual framebuffer
# to be used by the emulator when running with GPU acceleration.
# We also set the GPU mode to `host` to force the emulator to use
# GPU acceleration.
if [ "$GPU_ACCELERATED" == "true" ]; then
  export DISPLAY=":0.0"
  export GPU_MODE="host"
  Xvfb "$DISPLAY" -screen 0 1920x1080x16 -nolisten tcp &
else
  export GPU_MODE="swiftshader_indirect"
  ## Раскомментировать тогда, когда собираешь контейнер c API33 и выше
  #export GPU_MODE="swangle_indirect"
fi

# Asynchronously write updates on the standard output
# about the state of the boot sequence.
wait_for_boot &

# Start the emulator with no audio, no GUI, and no snapshots.
echo "Starting the emulator ..."
echo "OPTIONS:"
echo "SKIP ADB AUTH - $OPT_SKIP_AUTH"
echo "GPU           - $GPU_MODE"
echo "MEMORY        - $OPT_MEMORY"
echo "CORES         - $OPT_CORES"
emulator \
  -avd android \
  -gpu "$GPU_MODE" \
  -memory $OPT_MEMORY \
  -no-boot-anim \
  -dns-server 8.8.8.8 \
  -cores $OPT_CORES \
  -ranchu \
  $AUTH_FLAG \
  -no-window \
  -no-snapshot  || update_state "ANDROID_STOPPED"
