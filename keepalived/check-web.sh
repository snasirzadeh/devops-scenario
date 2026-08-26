#!/usr/bin/env bash

#set -x
set -Eeuo pipefail

curl -fsS --max-time 2 http://127.0.0.1/ > /dev/null
