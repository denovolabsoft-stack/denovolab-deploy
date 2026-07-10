#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="${LOG_FILE:-/var/log/class4-own-server-install.log}"
ENABLE_SSL="${ENABLE_SSL:-no}"
DOMAIN="${DOMAIN:-}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-}"
SKIP_PACKAGE_INSTALL="${SKIP_PACKAGE_INSTALL:-no}"

if [[ -z "${DNL_INSTALL_LOGGING_ACTIVE:-}" ]]; then
  export DNL_INSTALL_LOGGING_ACTIVE=1
  mkdir -p "$(dirname "$LOG_FILE")"
  exec > >(tee -a "$LOG_FILE") 2>&1
fi

die() {
  echo "ERROR: $*" >&2
  exit 1
}

is_enabled() {
  case "${1,,}" in
    1|yes|true|on) return 0 ;;
    *) return 1 ;;
  esac
}

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "Run this installer as root, for example: curl ... | sudo bash"
}

require_supported_os() {
  [[ -r /etc/os-release ]] || die "Cannot detect operating system."
  # shellcheck disable=SC1091
  source /etc/os-release

  local major="${VERSION_ID%%.*}"
  if [[ "$major" != "8" ]]; then
    die "This installer supports Rocky/RHEL-compatible Linux 8. Detected: ${PRETTY_NAME:-unknown}."
  fi

  case " ${ID:-} ${ID_LIKE:-} " in
    *" rocky "*|*" rhel "*|*" centos "*) ;;
    *) die "This installer supports Rocky/RHEL-compatible Linux 8. Detected: ${PRETTY_NAME:-unknown}." ;;
  esac
}

install_packages() {
  echo "Installing Class4 Fusion packages at $(date -u)."

  yum install -y dnf-plugins-core curl
  yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
  dnf module disable postgresql -y || true
  yum -y install postgresql15-server postgresql15-contrib prefix_15 ip4r_15
  yum install -y epel-release
  dnf config-manager --set-enabled powertools || \
    dnf config-manager --set-enabled PowerTools || \
    dnf config-manager --set-enabled crb || true
  yum install -y python3 python3-pip python3-wheel
  curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
  yum -y install nodejs
  yum install -y http://repo.denovolab.com/rocky/8/noarch/denovolab-rocky-1-1.noarch.rpm
  yum -y install dnl-database denovolabv6-software dnl_live_monitor

  sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config || true
  setenforce 0 || true
}

start_services() {
  systemctl enable nginx || true
  systemctl enable dnl_web_helper || true
  systemctl restart nginx || true
  systemctl restart dnl_web_helper || true
}

write_ssl_helper() {
  cat > /usr/local/sbin/class4-own-server-ssl.sh << 'SSLEOF'
#!/usr/bin/env bash
set -u

DOMAIN="$1"
EMAIL="${2:-}"
exec >> /var/log/class4-ssl.log 2>&1
echo "SSL setup start $(date -u) domain=$DOMAIN"

yum install -y epel-release dnf-plugins-core curl || true
yum install -y certbot python3-certbot-nginx

if grep -q "server_name" /etc/nginx/conf.d/denovo.conf; then
  sed -i "s/server_name .*/server_name $DOMAIN;/" /etc/nginx/conf.d/denovo.conf
else
  echo "server_name line not found in /etc/nginx/conf.d/denovo.conf"
fi

nginx -t && systemctl reload nginx || true

MATCHED=no
for i in $(seq 1 288); do
  PUBIP=$(curl -fsS --max-time 10 https://checkip.amazonaws.com 2>/dev/null | tr -d '[:space:]' || true)
  RESOLVED=$(getent ahostsv4 "$DOMAIN" | awk '{print $1}' | head -1)
  echo "check=$i public_ip=$PUBIP resolved=$RESOLVED"
  if [ -n "$PUBIP" ] && [ "$RESOLVED" = "$PUBIP" ]; then
    MATCHED=yes
    break
  fi
  sleep 300
done

if [ "$MATCHED" != "yes" ]; then
  echo "DNS for $DOMAIN never pointed to the server public IP in 24h."
  echo "After fixing DNS, run: /usr/local/sbin/class4-own-server-ssl.sh $DOMAIN $EMAIL"
  exit 1
fi

if [ -n "$EMAIL" ]; then
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect
else
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email --redirect
fi

API_INI=/opt/denovov6/api_dnl/api.ini
if [ -f "$API_INI" ]; then
  sed -i "s/^schema.*=.*/schema = https/" "$API_INI" || true
  sed -i "s/^hostname.*=.*/hostname = $DOMAIN/" "$API_INI" || true
fi

systemctl enable --now certbot-renew.timer 2>/dev/null || \
  echo "0 0,12 * * * root sleep \$((RANDOM % 3600)) && certbot renew -q" > /etc/cron.d/certbot-renew

systemctl restart nginx || true
systemctl restart dnl_web_helper || true
echo "SSL done: https://$DOMAIN/"
SSLEOF
  chmod 700 /usr/local/sbin/class4-own-server-ssl.sh
}

start_ssl_if_requested() {
  if ! is_enabled "$ENABLE_SSL"; then
    return
  fi

  [[ -n "$DOMAIN" ]] || die "DOMAIN is required when ENABLE_SSL=yes."
  write_ssl_helper
  nohup /usr/local/sbin/class4-own-server-ssl.sh "$DOMAIN" "$LETSENCRYPT_EMAIL" >/dev/null 2>&1 &
  echo "SSL setup started in background. Watch: tail -f /var/log/class4-ssl.log"
}

main() {
  require_root
  require_supported_os

  if ! is_enabled "$SKIP_PACKAGE_INSTALL"; then
    install_packages
  else
    echo "Skipping package install because SKIP_PACKAGE_INSTALL=$SKIP_PACKAGE_INSTALL."
  fi

  start_services
  start_ssl_if_requested

  echo "Class4 Fusion install finished at $(date -u)."
  echo "Open http://SERVER_PUBLIC_IP/ and complete the first-time setup wizard."
  echo "Install log: $LOG_FILE"
}

main "$@"
