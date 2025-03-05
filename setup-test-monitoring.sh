#!/bin/bash

# Запуск Minikube с 2 CPU и 4GB памяти
echo "🚀 Запускаем Minikube с 2 CPU и 4GB памяти..."
minikube start --driver=docker --memory=4096 --cpus=2

# Создание namespace для логов
echo "📁 Создаем namespace для логов..."
kubectl create namespace logs

# Добавление Helm репозиториев
echo "📦 Добавляем Helm репозитории..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Установка Loki
echo "⬇️ Устанавливаем Loki..."
helm install loki grafana/loki -f conf/loki-config.yaml -n logs

# Установка Promtail
echo "⬇️ Устанавливаем Promtail..."
kubectl apply -f conf/promtail-config.yaml

# Установка Prometheus
echo "⬇️ Устанавливаем Prometheus..."
helm install prometheus prometheus-community/prometheus -n logs

# Установка Grafana с источниками данных
echo "⬇️ Устанавливаем Grafana с источниками данных..."
helm install grafana grafana/grafana -n logs -f conf/grafana-sources.yaml

# Ожидание готовности подов
echo "⏳ Ожидаем запуска всех компонентов..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=loki -n logs --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n logs --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n logs --timeout=300s

# Настройка port-forwarding для Grafana и Prometheus
echo "🌐 Настраиваем доступ к портам..."
kubectl -n logs port-forward service/grafana 3000:80 --address=0.0.0.0 &> /dev/null &
kubectl -n logs port-forward service/prometheus-server 9090:80 --address=0.0.0.0 &> /dev/null &

# Получение учетных данных Grafana
echo "🔑 Получаем учетные данные Grafana..."
ADMIN_USER=$(kubectl -n logs get secret grafana -o jsonpath="{.data.admin-user}" | base64 -d)
ADMIN_PASS=$(kubectl -n logs get secret grafana -o jsonpath="{.data.admin-password}" | base64 -d)

# Вывод информации
echo "✅ Готово! Доступ к сервисам:"
echo "📊 Grafana: http://localhost:3000"
echo "👤 Логин: $ADMIN_USER"
echo "🔒 Пароль: $ADMIN_PASS"
echo "📈 Prometheus: http://localhost:9090"
echo "🛑 Для остановки: minikube stop"