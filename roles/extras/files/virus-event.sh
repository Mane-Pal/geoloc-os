#!/bin/bash
# ClamAV virus event handler
# Called when a virus is detected during on-access scanning

ALERT="Virus detected: $CLAM_VIRUSEVENT_VIRUSNAME in $CLAM_VIRUSEVENT_FILENAME"

# Log to syslog
logger -t clamav "$ALERT"

# Send desktop notification if possible
if command -v notify-send &>/dev/null; then
    notify-send -u critical "ClamAV Alert" "$ALERT"
fi
