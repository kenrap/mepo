#!/usr/bin/env sh

curlgraphhopper() {
  curl \
    -X POST \
    -H "Content-Type: application/json" \
    "https://graphhopper.com/api/1/route?key=$GRAPHHOPPER_API_KEY" \
    -d '
      {
        "elevation": false,
        "points_encoded": false,
        "points": [
          [-0.087891,51.534377],
          [-0.090637,51.467697]
        ],
        "vehicle": "car"
      }
    '
}

printpins() {
  RESPONSE="$1"

  COORDS="$(
    echo "$RESPONSE" | 
      jq '.paths[0].points.coordinates | .[] | join(" ")' | 
      tr -d '"'
  )"

  INSTRUCTIONS="$(
    echo "$RESPONSE" | 
      jq '
        .paths[0].instructions | 
        .[] | 
        "\(.interval[0]) \(.interval[1]) \(.text) (for \(.time)ms and \(.distance) meters)"
      ' |
      tr -d '"'
  )"

  echo "$INSTRUCTIONS" | while read -r LINE; do
    INSTRUCTIONSTART="$(echo "$LINE" | cut -d " " -f1)"
    STRUCTURALSTART="$(echo "$LINE" | cut -d " " -f1 | xargs -IEND echo END + 1 |  bc)"
    STRUCTURALEND="$(echo "$LINE" | cut -d " " -f2)"

    # Instructive pin
    echo $(
      printf "pin_add 0 "
      echo "$COORDS" | sed -n ${INSTRUCTIONSTART}p;
      printf "[";
      echo "$LINE" | cut -d ' ' -f3-;
      printf "];"
    )

    # Structural pins
    I="$STRUCTURALSTART"
    while [ "$I" -lt "$STRUCTURALEND" ]; do
      echo $(
        printf "pin_add 1 "
        echo "$COORDS" | sed -n ${I}p;
        printf ";"
      )
      I="$(echo $I + 1 | bc)"
    done
  done
}

errdie() {
  echo "$1"
  exit 1
}

main() {
  [ -z "$GRAPHHOPPER_API_KEY" ] && errdie 'Please export $GRAPHHOPPER_API_KEY'
  printpins "$(curlgraphhopper)"
}

main

