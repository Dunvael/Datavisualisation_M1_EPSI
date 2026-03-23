#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="loki-incident-generator"
IMAGE="alpine:3.20"

echo "==> Génération d'un incident de test pour Loki"
echo "==> Nom du conteneur : ${CONTAINER_NAME}"

docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

docker run --rm --name "${CONTAINER_NAME}" "${IMAGE}" /bin/sh -c '
i=1
while [ $i -le 30 ]; do
  ts=$(date -Iseconds)

  echo "$ts INFO incident=test service=demo-app message=\"Démarrage du scénario d incident Loki\""
  sleep 1

  echo "$ts WARN incident=test service=demo-app message=\"Montée anormale de la latence détectée\""
  sleep 1

  echo "$ts ERROR incident=test service=demo-app code=500 message=\"Echec connexion base MySQL simulé\""
  sleep 1

  echo "$ts ERROR incident=test service=demo-app code=503 message=\"Service temporairement indisponible\""
  sleep 1

  echo "$ts WARN incident=test service=demo-app message=\"Tentative de reprise automatique\""
  sleep 1

  i=$((i+1))
done

echo "$(date -Iseconds) INFO incident=test service=demo-app message=\"Fin du scénario de test Loki\""
'
