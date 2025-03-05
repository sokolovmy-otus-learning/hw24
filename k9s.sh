#!/bin/bash

# Проверка, что скрипт запущен с правами root
if [ "$EUID" -ne 0 ]; then
    echo "Пожалуйста, запустите скрипт с правами root (sudo)"
    exit 1
fi

# Установка зависимостей (curl для скачивания)
echo "Устанавливаем зависимости..."
apt-get update -y
apt-get install -y curl

# Определение последней версии k9s
echo "Получаем информацию о последней версии k9s..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep "tag_name" | cut -d '"' -f 4)

if [ -z "$LATEST_VERSION" ]; then
    echo "Не удалось определить последнюю версию k9s. Устанавливаем вручную заданную версию (например, v0.32.5)..."
    LATEST_VERSION="v0.32.5"
fi

echo "Последняя версия: $LATEST_VERSION"

# Определение архитектуры системы
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH_TYPE="amd64"
        ;;
    aarch64)
        ARCH_TYPE="arm64"
        ;;
    *)
        echo "Неподдерживаемая архитектура: $ARCH"
        exit 1
        ;;
esac

# Формирование URL для скачивания
DOWNLOAD_URL="https://github.com/derailed/k9s/releases/download/${LATEST_VERSION}/k9s_Linux_${ARCH_TYPE}.tar.gz"

# Скачивание архива
echo "Скачиваем k9s с $DOWNLOAD_URL..."
curl -L -o k9s.tar.gz "$DOWNLOAD_URL"

# Проверка успешности скачивания
if [ $? -ne 0 ]; then
    echo "Ошибка при скачивании k9s"
    exit 1
fi

# Распаковка архива
echo "Распаковываем архив..."
tar -xzf k9s.tar.gz

# Установка k9s в /usr/local/bin
echo "Устанавливаем k9s..."
mv k9s /usr/local/bin/k9s
chmod +x /usr/local/bin/k9s

# Очистка временных файлов
echo "Очищаем временные файлы..."
rm k9s.tar.gz

# Проверка установки
echo "Проверяем версию k9s..."
k9s version

# Вывод инструкций
echo "Установка завершена!"
echo "Запустите k9s командой: k9s"
echo "Для управления кластером Kubernetes используйте стрелки, Enter и другие клавиши (см. :help в k9s)"