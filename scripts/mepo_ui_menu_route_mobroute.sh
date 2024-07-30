#!/usr/bin/env sh
set -o pipefail
DISPLAYNAME=" Route: via Mobroute (Offline GTFS)"
HOTKEY=r
DOC='
  Allows user to route between the first two pins in the active pingroup
  via Mobroute. The route is calculated offline and GTFS data as needed is
  pulled automatically (see http://sr.ht/~mil/mobroute for details). The
  user is expected to provide the GTFS Feed ID (see http://mdb.lrdu.org)
  for details. The request maybe slow on initial routes and will be
  fast subsequently as GTFS data is cached locally. For this to work the
  user should install mobroute from their package manager and ensure the
  "mobroute" binary is in PATH.
'
[ -z "$MEPO_MOBROUTE_DEFAULTS" ] && MEPO_MOBROUTE_DEFAULTS="GTFS Feed ID|(please edit)
From Geocoordinate|GEOCORDFROM
To Geocoordinate|GEOCORDTO
Time|DATENOW
Tunable - Transfer Categories|f,i
Tunable - Max Walk Seconds|1200
Tunable - Max Trip Seconds|14400
Tunable - Min Transfer Seconds|180
Tunable - Max Transfer Seconds|2400
Tunable - Max N Transfers|20
Tunable - Walkspeed Km/Hr|4.5"


errdie() {
  zenity --error --text "$1"
  exit 1
}

ensurehasmobroute() {
  command -v mobroute >/dev/null || errdie "Binary mobroute missing; please install from your package manager"
}

gettablevals() {
  ERR_PINS="Must have atleast 2 pins in active pin group to route between!
    - Note: Please drop atleast two pins on the map to route between
    - Note: You can use the drop pin item in the central menu (or press f)
  "
  JSONPIN0="$(
    cat ~/.cache/mepo/shellpipe_savestate.json |
    jq "[.[] | select(.cmd == \"pin_add\" and .args.group == $MEPO_PINGROUPACTIVE)] | first"
  )"
  [ $? != 0 ] && errdie "$ERR_PINS"

  JSONPIN1="$(
    cat ~/.cache/mepo/shellpipe_savestate.json |
    jq "[.[] | select(.cmd == \"pin_add\" and .args.group == $MEPO_PINGROUPACTIVE)] | last"
  )"
  [ $? != 0 ] && errdie "$ERR_PINS"

  DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  COORDFROM="$(echo "$JSONPIN0" | jq '(.args.lat|tostring) + ", " + (.args.lon|tostring)' |tr -d '"')"
  COORDTO="$(echo "$JSONPIN1" | jq '(.args.lat|tostring) + ", " + (.args.lon|tostring)' |tr -d '"')"
    
  echo "$MEPO_MOBROUTE_DEFAULTS" | 
    sed "s#DATENOW#$DATE#g" |
    sed "s#GEOCORDFROM#$COORDFROM#g" |
    sed "s#GEOCORDTO#$COORDTO#g"
}

mapnlvalstojson() {
  jq -nR 'reduce inputs as $line ({}; .[$line] = input)'
}

zenitytableoutputtomobrouteparams() {
  INPUT="$(cat)"
  MOBROUTEPARAMS="$(
    echo "$INPUT" |
      jq '
        with_entries(if .key == "GTFS Feed ID" then (.key = "feed_ids" | .value = (.value | split(",") | map(. | tonumber))) else . end) |
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
  ERR_PARAMS="Unable to construct Mobroute args!
    - Note: You must select changed rows
    - Note: You must change GTFS Feed ID to a number value
  "
  [ $? != 0 ] && errdie "$ERR_PARAMS"
  echo "$MOBROUTEPARAMS"
}

mobrouterun() {
  RP="$1"
  TMPERR="$(mktemp)"
  MRRESULT="$(mobroute route -rp "{\"route_params\": $RP}" 2>$TMPERR)"
  [ $? != 0 ] && errdie "Mobroute Execution Error:\n$(cat $TMPERR)"
  echo "$MRRESULT"
}

main() {
  ensurehasmobroute
  MOBROUTE_ARGSPROMPT_TEXT="Mobroute Route
    - You may edit the route parameters below.
    - Note GTFS Feed ID is required!
    - See more details at: http://sr.ht/~mil/mobroute
    - Lookup Feed IDs at: http://mdb.lrdu.org
    - Common GTFS Feed IDs: (TODO)
    - Rows which were edited must be selected before hitting 'Route'\n\nParameters:"

  JSONBASE="$(gettablevals | tr '|' '\n' | mapnlvalstojson)"
  JSONSELECTRESULT="$(
    gettablevals |
      awk -F '|' '{printf "\"%s\" \"%s\" ", $1, $2}' |
      xargs zenity --ok-label Route --list --editable --multiple --text "$MOBROUTE_ARGSPROMPT_TEXT" --print-column ALL \
      --column "Parameter" \
      --column "Value" |
      tr '|' '\n' |
      mapnlvalstojson
  )"
  JSONRAWVALS="$(echo "[$JSONBASE, $JSONSELECTRESULT]" | jq add)"
  MOBROUTE_ROUTEPARAMS_BASE="$(echo "$JSONRAWVALS" | zenitytableoutputtomobrouteparams)"
  MOBROUTE_ROUTEPARAMS_ENABLEGEOJSON='{"output_formats": ["geojson"]}'
  MOBROUTE_ROUTEPARAMS="$(echo "[$MOBROUTE_ROUTEPARAMS_BASE, $MOBROUTE_ROUTEPARAMS_ENABLEGEOJSON]" | jq add)"
  MOBROUTE_GEOJSON_RESULT="$(mobrouterun "$MOBROUTE_ROUTEPARAMS")"
  echo "$MOBROUTE_GEOJSON_RESULT" | jq .geojson | mepo_geojson_import.sh
}

main