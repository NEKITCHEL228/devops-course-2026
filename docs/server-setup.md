# Инструкция по настройке сервера devops-vm

## 1. Базовая настройка системы
- ОС: Ubuntu Server 24.04 LTS (x86_64)
- Имя хоста: devops-vm
- Часовой пояс: Europe/Moscow

## 2. Пользователи и группы
- Пользователь `devops`: административный пользователь, входит в группы `sudo`, `devops`.
- Настройка sudo: файл `/etc/sudoers.d/devops` с директивой `devops ALL=(ALL) NOPASSWD: ALL`.
- Пользователь `student`: непривилегированный пользователь.

## 3. Сеть и межсетевой экран
- Сетевые интерфейсы:
  - `enp0s3`: NAT (доступ в интернет, проброс SSH на порт хоста 2222)
  - `enp0s8`: Host-only адаптер (статический IP `192.168.56.102/24`)
- UFW:
  - Политика по умолчанию: `incoming deny`, `outgoing allow`
  - Разрешённые порты: `22/tcp` (OpenSSH), `80/tcp` (HTTP), `443/tcp` (HTTPS).
- DNS: сопоставление `devops.local` -> `192.168.56.102` (хост) и `127.0.0.1` (ВМ).

## 4. SSH-сервер
- Порт: 22 (проброс хоста: 2222)
- Аутентификация: исключительно по публичным ключам Ed25519.
- Запрет входа root (`PermitRootLogin no`)
- Запрет паролей (`PasswordAuthentication no`)

## 5. Мониторинг и аудит
- Скрипт аудита: `scripts/audit.sh` (проверка соответствия конфигурации).

## 8. Веб-сервер и деплой
- Веб-сервер: Nginx 1.28.3
- Каталог сайта: `/var/www/devops-site`
  - Владелец: `devops:devops`
  - Права: каталоги `755` (`rwxr-xr-x`), файлы `644` (`rw-r--r--`)
- Виртуальный хост: `/etc/nginx/sites-available/devops-site` (симлинк в `sites-enabled`)
- SSL/TLS:
  - Сертификат: `/etc/ssl/certs/devops.crt` (RSA 2048, SAN `DNS:devops.local`, права `644`)
  - Закрытый ключ: `/etc/ssl/private/devops.key` (права `600`, владелец `root:root`)
- Перенаправление HTTP -> HTTPS: 301 Moved Permanently с порта 80 на 443.
- Кастомная страница ошибок: `404.html`.
- Деплой: скрипт `scripts/deploy.sh` с использованием `rsync`, флагом `--chmod=D755,F644` и smoke-тестом доступности сайта.
