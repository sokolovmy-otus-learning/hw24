
# 24. Kubernetes. Мониторинг и логирование // ДЗ

Разворачиваем локальный тестовый стенд мониторинга на базе Minikube с использованием Loki, Promtail, Prometheus и Grafana.

## Структура

- **`setup-test-monitoring.sh`** — Основной скрипт для развертывания мониторинга.
- **`conf/`** — Папка с файлами конфигурации:
  - `conf/loki-config.yaml` — Конфигурация Loki для Helm.
  - `conf/promtail-config.yaml` — Конфигурация Promtail (DaemonSet, ConfigMap, RBAC).
  - `conf/grafana-sources.yaml` — Настройки источников данных для Grafana (Loki и Prometheus).

## Требования

- ОС: Ubuntu (тестировалось на 24.04).
- Система имеет минимум 5GB свободной RAM и 2 ядра CPU.

## Установка зависимостей

Для установки зависимостей можно использовать скрипт `install-tools.sh`.

- Зависимости:
  - Docker
  - Minikube
  - kubectl
  - Helm

## Развертывание

1. Все файлы конфигурации должны находиться в папке `conf/`, при необходимости можно их изменить:

   - `conf/loki-config.yaml`
   - `conf/promtail-config.yaml`
   - `conf/grafana-sources.yaml`

2. Запускаем скрипт:

   ```bash
   ./setup-test-monitoring.sh
   ```

## Результат

После выполнения скрипта:

- **Grafana**: Доступна на `http://localhost:3000`.
  - Логин и пароль выводятся в консоль после запуска.
  - Источники данных: Loki и Prometheus (проверьте в `Configuration > Data Sources`).
- **Prometheus**: Доступен на `http://localhost:9090`.

## Остановка

Для остановки Minikube и всех сервисов:

```bash
minikube stop
```

Для полного удаления:

```bash
minikube delete
```
