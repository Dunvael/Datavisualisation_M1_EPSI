#!/usr/bin/env bash
set -euo pipefail
# ─────────────────────────────────────────────
# 🚀 Script de déploiement complet du TP Dataviz
# ─────────────────────────────────────────────

# --- Localisation du .env et chargement des variables pour le SHELL ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Fichier .env introuvable à la racine du projet : $ENV_FILE"
  exit 1
fi

# Exporter toutes les variables définies dans .env
set -a
. "$ENV_FILE"
set +a

# Vérifier les variables indispensables
: "${MYSQL_ROOT_PASSWORD:?Variable manquante dans .env}"
: "${MYSQL_EXPORTER_USER:?Variable manquante dans .env}"
: "${MYSQL_EXPORTER_PASSWORD:?Variable manquante dans .env}"

echo "=== 📦 Téléchargement des images ==="
docker compose pull

echo
echo "=== 🗄️  Démarrage du service MySQL ==="
docker compose up -d mysql

echo
echo "=== ⏳ Attente de la disponibilité de MySQL ==="
until docker exec mysql mysqladmin ping -h 127.0.0.1 -P 3306 -p"$MYSQL_ROOT_PASSWORD" --silent 2>/dev/null; do
  echo "⏳ MySQL n'est pas encore prêt..."; sleep 2
done
echo "✅ MySQL est prêt."

# Petit délai pour laisser le service totalement prêt
sleep 2

echo
echo "=== 👤 Création (ou mise à jour) de l'utilisateur exporter ==="
cat <<SQL | docker exec -i mysql mysql -h 127.0.0.1 -P 3306 -uroot -p"$MYSQL_ROOT_PASSWORD"
CREATE USER IF NOT EXISTS '${MYSQL_EXPORTER_USER}'@'%' IDENTIFIED BY '${MYSQL_EXPORTER_PASSWORD}';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO '${MYSQL_EXPORTER_USER}'@'%';
FLUSH PRIVILEGES;
SQL
echo "✅ Utilisateur exporter configuré."

echo
echo "=== 📊 Démarrage de la stack métriques + logs ==="
docker compose up -d prometheus grafana mysqld-exporter node-exporter-host node-exporter-node2 loki promtail

echo
echo "=== 🔍 Vérification rapide ==="
docker compose ps

echo
# Prometheus (déjà OK chez toi)
if curl -sf http://localhost:9090/-/healthy >/dev/null; then
  echo "✅ Prometheus OK"
else
  echo "❌ Prometheus KO"
fi

# Grafana: /api/health (sans auth) peut prendre quelques secondes au 1er démarrage
GRAFANA_WAIT=0
until curl -sf http://localhost:3000/api/health | grep -q '"database":"ok"'; do
  echo "⏳ Grafana pas encore prêt..."; sleep 2
  GRAFANA_WAIT=$((GRAFANA_WAIT+2))
  if [ "$GRAFANA_WAIT" -ge 60 ]; then
    echo "❌ Grafana KO (timeout). Regarde les logs: docker compose logs grafana"
    break
  fi
done
if [ "$GRAFANA_WAIT" -lt 60 ]; then echo "✅ Grafana OK"; fi

# Loki: /ready renvoie 200 + "ready" quand prêt
LOKI_WAIT=0
until curl -sf http://localhost:3100/ready >/dev/null; do
  echo "⏳ Loki pas encore prêt..."; sleep 2
  LOKI_WAIT=$((LOKI_WAIT+2))
  if [ "$LOKI_WAIT" -ge 60 ]; then
    echo "❌ Loki KO (timeout). Regarde les logs: docker compose logs loki"
    break
  fi
done
if [ "$LOKI_WAIT" -lt 60 ]; then echo "✅ Loki OK"; fi

echo
echo "✅ Déploiement complet terminé avec succès !"
echo "Grafana → http://localhost:3000 (admin / admin ou identifiants .env)"
echo "Prometheus → http://localhost:9090"
echo "Loki API → http://localhost:3100/ready"
