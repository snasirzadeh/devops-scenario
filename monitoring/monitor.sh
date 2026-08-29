#!/usr/bin/env bash

#set -x
set -Eeuo pipefail

LOG_DIR="/home/sepehr/github/devops-scenario/logs"
MONITOR_DIR="/home/sepehr/github/devops-scenario/monitoring"
DATE=$(date '+%Y%m%d')

ACCESS_LOG="$LOG_DIR/access.log-$DATE"
ERROR_LOG="$LOG_DIR/error.log-$DATE"

logme() {

    awk '{print $1}' "$ACCESS_LOG" |
        sort | uniq -c | sort -nr | head -3 > "$MONITOR_DIR/access.log"

    grep -E '(^|[^0-9])404([^0-9]|$)' "$ERROR_LOG" > "$MONITOR_DIR/error.log" || true
}
email() {
    mail \
        -s "Nginx Daily Monitoring Report - $DATE" \
        "debian" \
        < <(cat "$MONITOR_DIR/access.log.$DATE" "$MONITOR_DIR/error.log.$DATE")
}

logme
email

