#!/usr/bin/env bash

#set -x
set -Eeuo pipefail

rsync -az /home/user/.ssh/authorized_keys server2:/home/user/.ssh/authorized_keys
