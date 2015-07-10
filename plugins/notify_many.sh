#!/bin/bash
##
## QMON notification plugin - https://github.com/bef/qmon
##   notify via email, xmpp, ...
##

PLUGINDIR="`dirname $0`"

CONFIG="$1"; shift
NAME="$1"; shift
STATUS="$1"; shift
STATUS2="$1"; shift
CODE="$1"; shift
CMD="$1"; shift
OUTPUT="$1"; shift
PERFDATA="$1"; shift

. $CONFIG

MESSAGE="$NAME is now $STATUS2 (was $STATUS)\n$OUTPUT"
if [[ ! -z "$QMON_URL" ]]; then
	MESSAGE_WITH_URL="$MESSAGE\n--> $QMON_URL"
else
	MESSAGE_WITH_URL="$MESSAGE"
fi

## XMPP
if [[ ! -z "$JIDS" ]]; then
	echo -e "$MESSAGE_WITH_URL" | $PLUGINDIR/notify_via_xmpp $JIDS
fi

## PUSHOVER
if [[ $USE_PUSHOVER -ne 0 ]]; then
	$PLUGINDIR/notify_via_pushover -m "$MESSAGE" -bs -status "$STATUS2" -url "$QMON_URL"
fi

## EMAIL
if [[ ! -z "$EMAIL_RECIPIENTS" ]]; then
	for EMAIL in $EMAIL_RECIPIENTS; do
		echo -e "$MESSAGE_WITH_URL" | mailx -s "QMON ALERT ($NAME is $STATUS2)" "$EMAIL"
	done
fi
