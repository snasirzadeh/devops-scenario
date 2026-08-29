#!/usr/bin/env bash

#set -x
set -Eeuo pipefail

LOG_DIR="/home/user/devops-scenario/logs"
MONITOR_DIR="/home/user/devops-scenario/monitoring"
DATE=$(date '+%Y%m%d')
REPORT="$MONITOR_DIR/nginx.log.$DATE"

logme() {
    {
        echo "Top 3 IP addresses by request count:"
        grep -h "$(date '+%d/%b/%Y')" "$LOG_DIR"/access.log* |
            awk '{print $1}' |
            sort | uniq -c | sort -nr | head -3
        echo "----------------------------------------"
        echo "HTTP 404 Errors:"
        grep -h "$(date '+%d/%b/%Y')" "$LOG_DIR"/access.log* |
            awk '$9 == 404'
    } > "$REPORT"
}

email() {
    mail \
        -s "Nginx Daily Report - $DATE" \
        "debian" \
        < "$REPORT"
}

logme
email
