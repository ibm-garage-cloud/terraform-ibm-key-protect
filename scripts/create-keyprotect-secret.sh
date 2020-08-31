#!/usr/bin/env bash

NAMESPACE="$1"
REGION="$2"
KP_INSTANCE_ID="$3"

name="key-protect-access"

echo "Creating secret for key protect ${NAMESPACE}/${name}: ${REGION}, ${KP_INSTANCE_ID}"

kubectl create secret generic -n "${NAMESPACE}" key-protect-access \
  --from-literal=api-key="${API_KEY}" \
  --from-literal=region="${REGION}" \
  --from-literal=instance-id="${KP_INSTANCE_ID}"
