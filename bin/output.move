#!/usr/bin/env bash

export LC_ALL=C

set -o errexit -o pipefail

[ -z "$INBOX_CONF" ] && INBOX_CONF="/etc/default/inbox.conf"
eval "$(ini2bash "$INBOX_CONF")"

set -o nounset

file="$1"; shift

echo "$file: Moving to '${output_move[destination]}'" 1>&2

mv "$file" "${output_move[destination]}"/


