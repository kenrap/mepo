#!/usr/bin/env sh
set -o pipefail
DISPLAYNAME=" Route: via Mobroute (Offline GTFS)"
HOTKEY=R
DOC='
  TODO
'
[ -z "$MEPO_MOBROUTE_DEFAULTS" ] && MEPO_MOBROUTE_DEFAULTS="GTFS Feed ID|(please edit)
From Geocoordinate|282727.22222,73.333
To Geocoordinate|GEOCORDTO
Time|DATENOW
Tunable - Transfer Categories|f,i
Tunable - Max Walk Seconds|1200
Tunable - Max Trip Seconds|14400
Tunable - Min Transfer Seconds|180
Tunable - Max Transfer Seconds|2400
Tunable - Max N Transfers|20
Tunable - Walkspeed Km/Hr|4.5"

MOBROUTE_ARGSPROMPT_TEXT="Mobroute Route
  - You may edit the route parameters below.
  - Note GTFS Feed ID is required!
  - See more details at: http://sr.ht/~mil/mobroute
  - Lookup Feed IDs at: http://mdb.lrdu.org
  - Common GTFS Feed IDs: (TODO)
  - Rows which were edited must be selected before hitting 'Route'

Parameters:"

mobrouteargsprompt() {
  MEPO_MOBROUTE_DEFAULTS="$(
    echo "$MEPO_MOBROUTE_DEFAULTS" | 
    sed "s#DATENOW#$(date -u +'%Y-%m-%dT%H:%M:%SZ')#g" |
    sed "s#GEOCORDFROM#22.222,33.33#g" |
    sed "s#GEOCORDTO#22.222,33.33#g"
  )"

  # Pass the formatted input to zenity
  RESULT="$(
    echo "$MEPO_MOBROUTE_DEFAULTS" | 
      awk -F '|' '{printf "\"%s\" \"%s\" ", $1, $2}' |
      xargs zenity --ok-label Route --list --editable --multiple --text "$MOBROUTE_ARGSPROMPT_TEXT" --print-column ALL \
      --column "Parameter" \
      --column "Value"
  )"

  JSONARGS="$(
    echo "$RESULT" |
      tr '|' '\n' |
      jq -nR 'reduce inputs as $line ({}; .[$line] = input)' |
      jq '
        with_entries(if .key == "GTFS Feed ID" then (.key = "gtfs_feed_id" | .value = (.value | split(",") | map(. | tonumber))) else . end) |
        with_entries(if .key == "From Geocoordinate" then (.key = "from" | .value = (.value | split(",") | map(. | tonumber))) else . end) |
        with_entries(if .key == "To Geocoordinate" then (.key = "to" | .value = (.value | split(",") | map(. | tonumber))) else . end) |

        with_entries(if .key == "Time" then (.key = "time") else . end) |

        with_entries(if .key == "Tunable - Transfer Categories" then (.key = "transfer_categories" | .value = (.value | split(","))) else . end) |

        with_entries(if .key == "Tunable - Max Walk Seconds" then (.key = "max_walk_seconds" | .value = (.value | tonumber)) else . end) |
        with_entries(if .key == "Tunable - Max Trip Seconds" then (.key = "max_trip_seconds" | .value = (.value | tonumber)) else . end) |
        with_entries(if .key == "Tunable - Min Transfer Seconds" then (.key = "min_transfer_seconds" | .value = (.value | tonumber)) else . end) |
        with_entries(if .key == "Tunable - Max Transfer Seconds" then (.key = "max_transfer_seconds" | .value = (.value | tonumber)) else . end) |
        with_entries(if .key == "Tunable - Max N Transfers" then (.key = "max_n_transfers" | .value = (.value | tonumber)) else . end) |
        with_entries(if .key == "Tunable - Walkspeed Km/Hr" then (.key = "walkspeed_km_hr" | .value = (.value | tonumber)) else . end)
      '
  )"

  if [ $? != 0 ]; then
    zenity --error --text "Unable to construct Mobroute args
  - Note: You must select changed rows
  - Note: You must change GTFS Feed ID to a number value
  "
  fi
}

main() {
  JSONARGS="$(mobrouteargsprompt)"
  # TODO mobroute route -p "$JSONARGS"
}

main
