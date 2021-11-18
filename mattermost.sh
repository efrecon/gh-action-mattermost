#!/bin/sh

# This script is a wrapper for mattermost. It will authenticate at a cluster, and
# pass all further arguments to the kubectl binary. For some of the options, the
# script will attempt to guess the type of their value and convert to options
# that kubectl understands directly. When such conversions are performed, they
# happen in a temporary directory that is cleaned up after the kubeectl call.

set -eu

# Set this to 1 for more verbosity (on stderr)
MATTERMOST_VERBOSE=${MATTERMOST_VERBOSE:-0}


MATTERMOST_TEXT=${MATTERMOST_TEXT:-}
MATTERMOST_CHANNEL=${MATTERMOST_CHANNEL:-}
MATTERMOST_USERNAME=${MATTERMOST_USERNAME:-}
MATTERMOST_EMOJI=${MATTERMOST_EMOJI:-}
MATTERMOST_ICON=${MATTERMOST_ICON:-}
MATTERMOST_PROPS=${MATTERMOST_PROPS:-}
MATTERMOST_CARD=${MATTERMOST_CARD:-}


# This uses the comments behind the options to show the help. Not extremly
# correct, but effective and simple.
usage() {
  echo "$0 notifies mattermost at the hook passed as a parameter:" && \
    grep "[[:space:]].)\ #" "$0" |
    sed 's/#//' |
    sed -r 's/([a-z])\)/-\1/'
  exit "${1:-0}"
}

while getopts "t:c:u:e:i:p:r:vh-" opt; do
  case "$opt" in
    t) # Markdown-formatted message to display in the post
      MATTERMOST_TEXT=$OPTARG;;
    c) # Overrides the channel the message posts in. Use the channel’s name and not the display name.
      MATTERMOST_CHANNEL=$OPTARG;;
    u) # Defaults to the username set during webhook creation or the webhook creator’s username if the former was not set.
      MATTERMOST_USERNAME=$OPTARG;;
    e) # Overrides the profile picture and icon_url parameter. Defaults to none.
      MATTERMOST_EMOJI=$OPTARG;;
    i) # Overrides the profile picture the message posts with. Defaults to the URL set during webhook creation or the webhook creator’s profile picture if the former was not set.
      MATTERMOST_ICON=$OPTARG;;
    p) # Sets the post props, a JSON property bag for storing extra or meta data on the post.
      MATTERMOST_PROPS=$OPTARG;;
    r) # Sets the props to contain a card with this (markdown) content. Cannot be used if -p is specified.
      MATTERMOST_CARD=$OPTARG;;
    v) # Turn on verbosity
      MATTERMOST_VERBOSE=1;;
    h) # Print help and exit
      usage;;
    -)
      break;;
    *)
      usage 1;;
  esac
done
shift $((OPTIND-1))


_verbose() {
  if [ "$MATTERMOST_VERBOSE" = "1" ]; then
    printf %s\\n "$1" >&2
  fi
}

_error() {
  printf %s\\n "$1" >&2
}


# This will unfold JSON onliners to arrange for having fields and their values
# on separated lines. It's sed and grep, don't expect miracles, but this should
# work against most well-formatted JSON.
json_unfold() {
  sed -E \
      -e 's/\}\s*,\s*\{/\n\},\n\{\n/g' \
      -e 's/\{\s*"/\{\n"/g' \
      -e 's/(.+)\}/\1\n\}/g' \
      -e 's/"\s*:\s*(("[^"]+")|([a-zA-Z0-9]+))\s*([,$])/": \1\4\n/g' \
      -e 's/"\s*:\s*(("[^"]+")|([a-zA-Z0-9]+))\s*\}/": \1\n\}/g' | \
    grep -vEe '^\s*$'
}

# Provided some JSON has been unfold, i.e. one field and value per line, this
# will extract the values of all the fields which names are passed as a
# parameter.
json_field_val() {
  grep -E "\"$1\"" |
  sed -E \
    -e "s/\\s*\"$1\"\\s*:\\s*((\"[^\"]+\")|([a-zA-Z0-9]+)).*/\\1/g" \
    -e 's/^"//' \
    -e 's/"$//'
}

json_field_print_raw() {
  _verbose "Adding $1 to Mattermost notifiaction payload: $2"
  printf '"%s": %s,\n' "$1" "$2"
}

json_field_print_string() {
  json_field_print_raw "$1" "\"$2\""
}

if [ "$#" -lt "1" ]; then
  usage 1
fi

if ! command -v curl >/dev/null 2>&1; then
  _error "This script requires curl installed on the host"
  exit
fi

# Create a temporary directory for file storage, this will be used to create the
# JSON payload to be sent to the mattermost server.
TMPD=$(mktemp -t -d mattermost-XXXXX)

# Prepare some pseudo-JSON object, based on the content of the incoming
# parameters. This will always print out a comma too much, on the last line. We
# are going to remove it later.
json_field_print_string text "$MATTERMOST_TEXT" > "${TMPD}/raw.json"
if [ -n "$MATTERMOST_CHANNEL" ]; then
  json_field_print_string channel "$MATTERMOST_CHANNEL" >> "${TMPD}/raw.json"
fi
if [ -n "$MATTERMOST_USERNAME" ]; then
  json_field_print_string username "$MATTERMOST_USERNAME" >> "${TMPD}/raw.json"
fi
if [ -n "$MATTERMOST_ICON" ]; then
  json_field_print_string icon_url "$MATTERMOST_ICON" >> "${TMPD}/raw.json"
fi
if [ -n "$MATTERMOST_EMOJI" ]; then
  json_field_print_string icon_emoji "$MATTERMOST_EMOJI" >> "${TMPD}/raw.json"
fi
if [ -n "$MATTERMOST_PROPS" ]; then
  json_field_print_raw props "$MATTERMOST_PROPS" >> "${TMPD}/raw.json"
elif [ -n "$MATTERMOST_CARD" ]; then
  json_field_print_raw props "{\"card\": \"${MATTERMOST_CARD}\"}" >> "${TMPD}/raw.json"
fi

# Construct a proper JSON payload out of the raw JSON.
{
  printf '{\n'
  head -n -1 "${TMPD}/raw.json"
  tail -n 1 "${TMPD}/raw.json" | sed -E 's/,$//'
  printf '}\n'
} > "${TMPD}/payload.json"

# Use curl to send the payload and make the result of curl the result of this
# script
EXIT_CODE=0
_verbose "Sending payload to mattermost hook $1"
response=$(curl -sSL \
            -H "Content-Type: application/json" \
            -d @"${TMPD}/payload.json" \
            "$1")
if ! [ "$response" = "ok" ]; then
  status_code=$(printf %s\\n "$response"|json_unfold|json_field_val "status_code")
  message=$(printf %s\\n "$response"|json_unfold|json_field_val "message")
  EXIT_CODE=1
  _error "Could not notify Mattermost ($status_code): $message"
fi

rm -rf "$TMPD"
exit "$EXIT_CODE"
