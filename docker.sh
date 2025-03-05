#!/bin/bash

# Проверка, что скрипт запущен с правами root
if [ "$EUID" -ne 0 ]; then
    echo "Пожалуйста, запустите скрипт с правами root (sudo)"
    exit 1
fi

# Обновление списка пакетов
echo "Обновляем список пакетов..."
apt-get update -y

# Установка необходимых зависимостей
echo "Устанавливаем зависимости..."
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Добавление официального GPG-ключа Docker
echo "Добавляем GPG-ключ Docker..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Добавление репозитория Docker
echo "Добавляем репозиторий Docker..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Обновление списка пакетов после добавления репозитория
echo "Обновляем список пакетов с новым репозиторием..."
apt-get update -y

# Установка Docker Engine, CLI и Containerd
echo "Устанавливаем Docker..."
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# Проверка статуса Docker
echo "Проверяем статус Docker..."
systemctl status docker --no-pager
if [ $? -ne 0 ]; then
    echo "Запускаем и включаем Docker..."
    systemctl start docker
    systemctl enable docker
fi

# Добавление текущего пользователя в группу docker (для использования без sudo)
echo "Настраиваем использование Docker без sudo..."
CURRENT_USER=$(logname)
usermod -aG docker $CURRENT_USER

# Проверка версии Docker
echo "Проверяем установленную версию Docker..."
docker --version

# Тестовый запуск контейнера
echo "Запускаем тестовый контейнер hello-world..."
docker run --rm hello-world

# Вывод инструкций
echo "Установка завершена!"
echo "Docker установлен и настроен."
echo "Для применения прав группы docker без sudo, выполните 'newgrp docker' или перелогиньтесь."
echo "Проверьте Docker командой: docker --version"
echo "Запустите тестовый контейнер: docker run hello-world"