#!/usr/bin/env bash

set -euo pipefail

PORT=1337

ssh \
  -X -CY \
  -p ${PORT} \
  -o UserKnownHostsFile=/dev/null \
  -o StrictHostKeyChecking=no \
  -o LogLevel=ERROR \
  archimedes@localhost
