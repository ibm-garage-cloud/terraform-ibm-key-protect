#!/usr/bin/env bash

NAMESPACE="$1"

name="key-protect-access"

echo "Deleting secret for key protect ${NAMESPACE}/${name}"

kubectl delete secret -n "${NAMESPACE}" "${name}"
