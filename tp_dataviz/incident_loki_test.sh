#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="loki-incident-test"
IMAGE="alpine:3.20"

echo "==> Simulation d'un incident applicatif"

docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true

MSYS_NO_PATHCONV=1 docker run \
  --name "${CONTAINER_NAME}" \
  "${IMAGE}" //bin/sh -c '
echo "INFO Starting demo-app service"
sleep 2
echo "WARN High response time detected"
sleep 2
echo "ERROR Database connection failed"
sleep 2
echo "ERROR Timeout while calling external API"
sleep 2
echo "ERROR Stacktrace:"
echo "java.lang.RuntimeException: Database unreachable"
echo "    at com.example.Service.connect(Service.java:42)"
echo "    at com.example.Controller.handle(Controller.java:15)"
sleep 2
echo "INFO Attempting recovery"
sleep 2
echo "INFO Service restored"
sleep 300
'