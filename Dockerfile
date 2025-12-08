FROM openjdk:18-ea-jdk-slim-bullseye

ENV DEBIAN_FRONTEND noninteractive

#WORKDIR /
#=============================
# Установить зависимости
#=============================
SHELL ["/bin/bash", "-c"]

RUN apt update && apt install -y curl \
	sudo wget unzip bzip2 libdrm-dev \
	libxkbcommon-dev libgbm-dev libasound-dev libnss3 \
	libxcursor1 libpulse-dev libxshmfence-dev \
	xauth xvfb x11vnc fluxbox wmctrl libdbus-glib-1-2 socat \
	virt-manager


# Лейблы Docker.
LABEL maintainer "Yelissey Oshlokov <elisey.oshlokov@onetwotrip.com>"
LABEL description "A Docker image for API 31"
LABEL version "1.0.1"

# Аргументы, которые можно переопределить во время сборки.
ARG INSTALL_ANDROID_SDK=1
ARG API_LEVEL=31
ARG IMG_TYPE=google_apis
ARG ARCHITECTURE=x86_64
ARG CMD_LINE_VERSION=9477386_latest
# Для API от 33 и выше
# ARG CMD_LINE_VERSION=13114758_latest
ARG DEVICE_ID=pixel
ARG GPU_ACCELERATED=false

# Переменные окружения.
ENV ANDROID_SDK_ROOT=/opt/android \
	ANDROID_PLATFORM_VERSION="platforms;android-$API_LEVEL" \
	PACKAGE_PATH="system-images;android-${API_LEVEL};${IMG_TYPE};${ARCHITECTURE}" \
	API_LEVEL=$API_LEVEL \
	DEVICE_ID=$DEVICE_ID \
	ARCHITECTURE=$ARCHITECTURE \
	ABI=${IMG_TYPE}/${ARCHITECTURE} \
	GPU_ACCELERATED=$GPU_ACCELERATED \
	QTWEBENGINE_DISABLE_SANDBOX=1 \
	ANDROID_EMULATOR_WAIT_TIME_BEFORE_KILL=120 \
	ANDROID_AVD_HOME=/data

# Экспорт переменных окружения, чтобы пути к
# бинарникам и общим библиотекам Android SDK были в PATH.
ENV PATH "${PATH}:${ANDROID_SDK_ROOT}/platform-tools"
ENV PATH "${PATH}:${ANDROID_SDK_ROOT}/emulator"
ENV PATH "${PATH}:${ANDROID_SDK_ROOT}/cmdline-tools/tools/bin"
ENV LD_LIBRARY_PATH "$ANDROID_SDK_ROOT/emulator/lib64:$ANDROID_SDK_ROOT/emulator/lib64/qt/lib"

# Установить рабочую директорию /opt
WORKDIR /opt

# Открыть порт консоли эмулятора Android
# и порт ADB.
EXPOSE 5554 5555

# Инициализация необходимых директорий.
RUN mkdir /root/.android/ && \
	touch /root/.android/repositories.cfg && \
	mkdir /data

# Экспортировать ключи ADB.
COPY keys/* /root/.android/

# Следующие слои загрузят инструменты командной строки Android,
# чтобы установить Android SDK, эмулятор и образы системы.
# Затем будет установлен Android SDK и эмулятор.
COPY scripts/install-sdk.sh /opt/
RUN chmod +x /opt/install-sdk.sh
RUN /opt/install-sdk.sh

# Скопировать скрипты контейнера в образ.
COPY scripts/start-emulator.sh /opt/
COPY scripts/emulator-monitoring.sh /opt/
RUN chmod +x /opt/*.sh

#  Точка входа
ENTRYPOINT ["/opt/start-emulator.sh"]
