#!/bin/bash

# Проверка наличия Minikube
if ! command -v minikube &> /dev/null; then
    echo "⚠️ Minikube не установлен. Устанавливаем..."
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
fi

# Проверка наличия kubectl
if ! command -v kubectl &> /dev/null; then
    echo "⚠️ kubectl не установлен. Устанавливаем..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
fi

# Запуск Minikube с уменьшенными требованиями
echo "🚀 Запускаем Minikube с уменьшенными требованиями..."
minikube start --driver=docker --memory=2048 --cpus=2

# Создание namespace для логов
echo "📁 Создаем namespace для логов..."
kubectl create namespace logs

# Создание файла конфигурации Loki
echo "⚙️ Создаем файл конфигурации Loki..."
cat << EOF > loki-config.yaml
deploymentMode: SingleBinary
loki:
  auth_enabled: false
  commonConfig:
    replication_factor: 1
  server:
    http_listen_port: 3100
  storage:
    type: 'filesystem'
  schemaConfig:
    configs:
    - from: "2025-01-01"
      store: tsdb
      index:
        prefix: loki_index_
        period: 24h
      object_store: filesystem
      schema: v13
chunksCache:
  enabled: true
  allocatedMemory: 1024
singleBinary:
  replicas: 1
read:
  replicas: 0
backend:
  replicas: 0
write:
  replicas: 0
EOF

# Создание файла конфигурации Promtail
echo "⚙️ Создаем файл конфигурации Promtail..."
cat << EOF > promtail-config.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: promtail-daemonset
  namespace: logs
spec:
  selector:
    matchLabels:
      name: promtail
  template:
    metadata:
      labels:
        name: promtail
    spec:
      serviceAccount: promtail-serviceaccount
      containers:
      - name: promtail-container
        image: grafana/promtail
        args:
        - -config.file=/etc/promtail/promtail.yaml
        env:
        - name: 'HOSTNAME'
          valueFrom:
            fieldRef:
              fieldPath: 'spec.nodeName'
        volumeMounts:
        - name: logs
          mountPath: /var/log
        - name: promtail-config
          mountPath: /etc/promtail
        - mountPath: /var/lib/docker/containers
          name: varlibdockercontainers
          readOnly: true
      volumes:
      - name: logs
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      - name: promtail-config
        configMap:
          name: promtail-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: promtail-config
  namespace: logs
data:
  promtail.yaml: |
    server:
      http_listen_port: 9080
      grpc_listen_port: 0
    clients:
    - url: http://loki-gateway.logs.svc.cluster.local/loki/api/v1/push
    positions:
      filename: /tmp/positions.yaml
    target_config:
      sync_period: 10s
    scrape_configs:
    - job_name: pod-logs
      kubernetes_sd_configs:
        - role: pod
      pipeline_stages:
        - docker: {}
      relabel_configs:
        - source_labels:
            - __meta_kubernetes_pod_node_name
          target_label: __host__
        - action: labelmap
          regex: __meta_kubernetes_pod_label_(.+)
        - action: replace
          replacement: $1
          separator: /
          source_labels:
            - __meta_kubernetes_namespace
            - __meta_kubernetes_pod_name
          target_label: job
        - action: replace
          source_labels:
            - __meta_kubernetes_namespace
          target_label: namespace
        - action: replace
          source_labels:
            - __meta_kubernetes_pod_name
          target_label: pod
        - action: replace
          source_labels:
            - __meta_kubernetes_pod_container_name
          target_label: container
        - replacement: /var/log/pods/*$1/*.log
          separator: /
          source_labels:
            - __meta_kubernetes_pod_uid
            - __meta_kubernetes_pod_container_name
          target_label: __path__
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: promtail-clusterrole
rules:
  - apiGroups: [""]
    resources:
    - nodes
    - services
    - pods
    verbs:
    - get
    - watch
    - list
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: promtail-serviceaccount
  namespace: logs
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: promtail-clusterrolebinding
subjects:
    - kind: ServiceAccount
      name: promtail-serviceaccount
      namespace: logs
roleRef:
    kind: ClusterRole
    name: promtail-clusterrole
    apiGroup: rbac.authorization.k8s.io
EOF

# Создание файла значений для Grafana с источниками данных
echo "⚙️ Создаем файл значений для Grafana..."
cat << EOF > grafana-values.yaml
additionalDataSources:
  - name: Loki
    type: loki
    url: http://loki.logs.svc.cluster.local:3100
    access: proxy
  - name: Prometheus
    type: prometheus
    url: http://prometheus-server.logs.svc.cluster.local
    access: proxy
EOF

# Создание манифеста для источников данных как запасной вариант
echo "⚙️ Создаем манифест для источников данных Grafana..."
cat << EOF > grafana-datasources.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: logs
  labels:
    grafana_datasource: "1"
data:
  datasources.yaml: |
    apiVersion: 1
    datasources:
    - name: Loki
      type: loki
      url: http://loki.logs.svc.cluster.local:3100
      access: proxy
      isDefault: false
    - name: Prometheus
      type: prometheus
      url: http://prometheus-server.logs.svc.cluster.local
      access: proxy
      isDefault: true
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: logs
spec:
  template:
    spec:
      volumes:
      - name: datasources
        configMap:
          name: grafana-datasources
      containers:
      - name: grafana
        volumeMounts:
        - name: datasources
          mountPath: "/etc/grafana/provisioning/datasources"
EOF

# Установка Helm если не установлен
if ! command -v helm &> /dev/null; then
    echo "⚠️ Helm не установлен. Устанавливаем..."
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
    chmod +x get_helm.sh
    ./get_helm.sh
    rm get_helm.sh
fi

# Добавление Helm репозиториев
echo "📦 Добавляем Helm репозитории..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Установка Loki
echo "⬇️ Устанавливаем Loki..."
helm install loki grafana/loki -f loki-config.yaml -n logs

# Установка Promtail
echo "⬇️ Устанавливаем Promtail..."
kubectl apply -f promtail-config.yaml

# Установка Prometheus
echo "⬇️ Устанавливаем Prometheus..."
helm install prometheus prometheus-community/prometheus -n logs

# Установка Grafana с источниками данных
echo "⬇️ Устанавливаем Grafana с источниками данных..."
helm install grafana grafana/grafana -n logs -f grafana-values.yaml \
  --set "datasources.datasources\.yaml.apiVersion=1" \
  --set "datasources.datasources\.yaml.datasources[0].name=Loki" \
  --set "datasources.datasources\.yaml.datasources[0].type=loki" \
  --set "datasources.datasources\.yaml.datasources[0].url=http://loki.logs.svc.cluster.local:3100" \
  --set "datasources.datasources\.yaml.datasources[0].access=proxy" \
  --set "datasources.datasources\.yaml.datasources[1].name=Prometheus" \
  --set "datasources.datasources\.yaml.datasources[1].type=prometheus" \
  --set "datasources.datasources\.yaml.datasources[1].url=http://prometheus-server.logs.svc.cluster.local" \
  --set "datasources.datasources\.yaml.datasources[1].access=proxy"

# Ожидание готовности подов
echo "⏳ Ожидаем запуска всех компонентов..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=loki -n logs --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n logs --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n logs --timeout=300s

# Диагностика: проверка значений Helm
echo "🔍 Проверяем примененные Helm-значения для Grafana..."
helm -n logs get values grafana

# Перезапуск Grafana для применения источников данных
echo "🔄 Перезапускаем Grafana для применения источников данных..."
kubectl -n logs rollout restart deployment grafana

# Ожидание перезапуска Grafana
echo "⏳ Ожидаем перезапуска Grafana..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n logs --timeout=300s

# Резервный вариант: применение источников данных через ConfigMap
echo "⚠️ Проверяем наличие источников данных и применяем резервный вариант, если нужно..."
kubectl -n logs describe pod -l app.kubernetes.io/name=grafana | grep -q "datasources.yaml"
if [ $? -ne 0 ]; then
    echo "Источники данных не применились через Helm, применяем ConfigMap..."
    kubectl apply -f grafana-datasources.yaml
    kubectl -n logs rollout restart deployment grafana
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n logs --timeout=300s
fi

# Настройка постоянного port-forwarding для Grafana и Prometheus
echo "🌐 Настраиваем постоянный доступ к портам..."
kubectl -n logs port-forward service/grafana 3000:80 --address=0.0.0.0 &
kubectl -n logs port-forward service/prometheus-server 9090:80 --address=0.0.0.0 &

# Получение и вывод учетных данных Grafana
echo "🔑 Получаем учетные данные Grafana..."
ADMIN_USER=$(kubectl -n logs get secret grafana -o jsonpath="{.data.admin-user}" | base64 -d)
ADMIN_PASS=$(kubectl -n logs get secret grafana -o jsonpath="{.data.admin-password}" | base64 -d)

# Вывод информации о доступе
echo "✅ Готово! Доступ к сервисам:"
echo "📊 Grafana: http://localhost:3000 (включает Loki и Prometheus как источники данных)"
echo "👤 Логин: $ADMIN_USER"
echo "🔒 Пароль: $ADMIN_PASS"
echo "📈 Prometheus: http://localhost:9090"
echo "ℹ️ Примечание: Все сервисы доступны постоянно до остановки Minikube"
echo "🛑 Для остановки: minikube stop"
echo "🔍 Для проверки источников данных: зайдите в Grafana -> Configuration -> Data Sources"