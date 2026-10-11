#!/usr/bin/env bash
#
# scripts/audit.sh — Комплексный аудит сервера devops-vm
# Практические работы №5 и №6
#

set -uo pipefail

FAILED=0

check() {
    local name="$1"
    shift
    if "$@"; then
        echo "[OK]   $name"
    else
        echo "[FAIL] $name"
        FAILED=1
    fi
}

echo "=========================================="
echo " Аудит безопасности и сервисов devops-vm"
echo "=========================================="

echo "--- [1] Базовая система и пользователи ---"
check "Имя хоста: devops-vm" test "$(hostname)" = "devops-vm"
check "Пользователь devops существует" id devops
check "Пользователь student существует" id student
check "Файл sudoers для devops настроен" test -f /etc/sudoers.d/devops

echo "--- [2] Сеть и межсетевой экран (UFW) ---"
check "Служба UFW активна" ufw status | grep -q "Status: active"
check "Порт 22/tcp открыт в UFW" ufw status | grep -q "22/tcp.*ALLOW"
check "Порт 80/tcp открыт в UFW" ufw status | grep -q "80/tcp.*ALLOW"
check "Порт 443/tcp открыт в UFW" ufw status | grep -q "443/tcp.*ALLOW"

echo "--- [3] Служба SSH ---"
check "Служба ssh активна" systemctl is-active --quiet ssh
check "Порт 22 слушается" ss -tln | grep -q ":22 "

echo "--- [4] Веб-сервер (Nginx и TLS) ---"
check "Служба nginx активна" systemctl is-active --quiet nginx
check "Порт 80 (HTTP) прослушивается" ss -tlnp | grep -q ":80 "
check "Порт 443 (HTTPS) прослушивается" ss -tlnp | grep -q ":443 "
check "Сертификат /etc/ssl/certs/devops.crt существует" test -f /etc/ssl/certs/devops.crt
check "Сертификат выдан для devops.local" openssl x509 -in /etc/ssl/certs/devops.crt -noout -subject | grep -q "CN=devops.local"
check "Закрытый ключ /etc/ssl/private/devops.key защищен (600)" test "$(stat -c %a /etc/ssl/private/devops.key 2>/dev/null)" = "600"
check "Каталог сайта /var/www/devops-site доступен" test -d /var/www/devops-site
check "HTTPS ответ 200 OK на https://devops.local" bash -c "curl -k -s -o /dev/null -w '%{http_code}' https://devops.local | grep -q '200'"

echo "=========================================="
if [[ $FAILED -eq 0 ]]; then
    echo "ИТОГ: Все проверки успешно пройдены! (код 0)"
    exit 0
else
    echo "ИТОГ: Обнаружены ошибки конфигурации! (код 1)"
    exit 1
fi
