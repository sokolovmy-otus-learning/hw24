#!/bin/bash

# Обновление пакетов
echo "🔄 Обновляем список пакетов..."
sudo apt-get update -y

# Установка зависимостей
echo "⚙️ Устанавливаем базовые зависимости..."
sudo apt-get install -y curl apt-transport-https ca-certificates gnupg lsb-release

# 1. Установка Docker
echo "🐳 Устанавливаем Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker $USER
echo "🔧 Применяем права для Docker..."
newgrp docker
echo "✅ Docker установлен! Версия:"
docker --version

# 2. Установка Minikube
echo "🚀 Устанавливаем Minikube..."
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64
echo "✅ Minikube установлен! Версия:"
minikube version

# 3. Установка kubectl
echo "⚙️ Устанавливаем kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
echo "✅ kubectl установлен! Версия:"
kubectl version --client

# 4. Установка k9s
echo "🖥️ Устанавливаем k9s..."
LATEST_K9S=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep "tag_name" | cut -d '"' -f 4)
curl -L "https://github.com/derailed/k9s/releases/download/${LATEST_K9S}/k9s_Linux_amd64.tar.gz" -o k9s.tar.gz
tar -xzf k9s.tar.gz
sudo mv k9s /usr/local/bin/
rm k9s.tar.gz
echo "✅ k9s установлен! Версия:"
k9s version

# Вывод инструкций
echo "✅ Установка завершена!"
echo "📌 Проверьте установку:"
echo "   docker run hello-world"
echo "   minikube start --driver=docker"
echo "   kubectl get nodes"
echo "   k9s"