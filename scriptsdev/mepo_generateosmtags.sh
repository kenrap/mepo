#!/usr/bin/env sh
# Pulls from taginfo.openstreemap.org to determine most used tags
# and generates a script that just dumps that list
#
# Regeneration example: 
# ./scriptsdev/mepo_generateosmtags.sh > scripts/mepo_generated_osmtags.sh

generate() {
  KEY="$1"
  NITEMS="$2"

  JSON="$(
    curl 'https://taginfo.openstreetmap.org/api/4/key/values?key='${KEY}'&filter=all&lang=en&sortname=count&sortorder=desc&page=1&rp='${NITEMS}'&qtype=value&format=json_pretty'
  )"

  echo "$JSON" | 
    jq '
      .data | 
      .[] | 
      "['$KEY'=\(.value)]: \(
        if (.description != "" and .description != null)
          then .description 
          else .value 
          end 
        )
      "
    ' | tr -d '"' | sed -E 's/\\n//g'
}

generatescript() {
  echo "#!/usr/bin/env sh"
  echo "# Generated via mepo's development script $(basename $0)"
  echo "# This script just prints a list of the top amenity tags from OSM's taginfo db"
  echo "# Regenerated at development time / per-release"
  echo 'echo "'
  generate amenity 999
  generate cuisine 999
  echo '"'
}

generatescript
