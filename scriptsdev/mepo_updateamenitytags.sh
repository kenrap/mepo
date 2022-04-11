#!/usr/bin/env sh
# Pulls from taginfo.openstreemap.org to determine most used amenity tags
# and generates a script that just dumps that list
#
# Regeneration example: 
# ./scriptsdev/mepo_updateamenitytags.sh > scripts/mepo_amenitytags.sh

generate() {
  JSON="$(
    curl 'https://taginfo.openstreetmap.org/api/4/key/values?key=amenity&filter=all&lang=en&sortname=count&sortorder=desc&page=1&rp=999&qtype=value&format=json_pretty'
  )"

  echo "$JSON" | 
    jq '
      .data | 
      .[] | 
      "[ammenity=\(.value)]: \(
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
  echo "# Generated via mepo's development script $0"
  echo "# This script just prints a list of the top amenity tags from OSM's taginfo db"
  echo "# Regenerated at development time / per-release"
  echo 'echo "'
  generate
  echo '"'
}

generatescript
