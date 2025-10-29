#!/usr/bin/env bash
set -euo pipefail
# ─────────────────────────────────────────────
# 🚀 Script de déploiement complet du TP Dataviz
# ─────────────────────────────────────────────

echo "=== 📦 Téléchargement des images ==="
docker compose pull

echo
echo "=== 🗄️  Démarrage du service MySQL ==="
docker compose up -d mysql

echo
echo "=== ⏳ Attente de la disponibilité de MySQL ==="
until docker exec mysql mysqladmin ping -p"$MYSQL_ROOT_PASSWORD" --silent 2>/dev/null; do
  echo "⏳ MySQL n'est pas encore prêt..."; sleep 2
done
echo "✅ MySQL est prêt."

echo
echo "=== 👤 Création (ou mise à jour) de l'utilisateur exporter ==="
cat <<SQL | docker exec -i mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD"
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
curl -sf http://localhost:9090/-/healthy && echo "✅ Prometheus OK" || echo "❌ Prometheus KO"
curl -sI http://localhost:3000 | head -n1 | grep "200" >/dev/null && echo "✅ Grafana OK" || echo "❌ Grafana KO"
curl -sf http://localhost:3100/ready && echo "✅ Loki OK" || echo "❌ Loki KO"

echo
echo "✅ Déploiement complet terminé avec succès !"
echo "Grafana → http://localhost:3000 (admin / admin ou identifiants .env)"
echo "Prometheus → http://localhost:9090"
echo "Loki API → http://localhost:3100/ready"