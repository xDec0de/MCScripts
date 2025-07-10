#!/bin/bash

echo 
echo "   ___   ___   _  __  ___                          _                   _              "
echo "  / __| / __| | |/ / |   \   ___  __ __ __  _ _   | |  ___   __ _   __| |  ___   _ _  "
echo " | (__  \\__ \\ | ' <  | |) | / _ \\ \\ V  V / | ' \\  | | / _ \\ / _\` | / _\` | / -_) | '_| "
echo "  \___| |___/ |_|\_\ |___/  \___/  \_/\_/  |_||_| |_| \___/ \__,_| \__,_| \___| |_|   "
echo "                                                                                      "    
echo 

# --------------------------------------------------------------------------- #
#                             Global variables
# --------------------------------------------------------------------------- #

PLUGINS_FOLDER="./plugins"

# --------------------------------------------------------------------------- #
#                             Dependency check
# --------------------------------------------------------------------------- #

if ! command -v curl >/dev/null 2>&1; then
  echo 
  echo "curl is not installed. Please install curl and try again."
  echo 
  exit 1
fi

# --------------------------------------------------------------------------- #
#                            Plugin file creation
# --------------------------------------------------------------------------- #

PLUGIN_FILE="mcsplugins"

# Check if file doesn't exist
if [ ! -f "$PLUGIN_FILE" ]; then
  touch $PLUGIN_FILE
  echo "Plugins file created. Please add plugin links to it."
  exit 0
fi

# --------------------------------------------------------------------------- #
#                          Spigot link processing
# --------------------------------------------------------------------------- #

SPIGET_URL="https://api.spiget.org/v2/resources"
SPIGOT_URL="https://www.spigotmc.org"

# Function to process spigot links
process_spigot_link() {
  local url="$1"

  # Remove trailing slash if present
  url="${url%/}"

  # Extract numeric ID after last dot
  local id="${url##*.}"

  # Validate that the id is numeric
  if [[ ! "$id" =~ ^[0-9]+$ ]]; then
    echo "- Invalid Spigot plugin. Reason: $id is an invalid plugin id"
    return
  fi

  download_plugin "$SPIGET_URL/$id/download" "$id" "spigot"
}

# --------------------------------------------------------------------------- #
#                      Generic plugin download function
# --------------------------------------------------------------------------- #

download_plugin() {
  local url="$1"
  local filename="$2"
  local source="$3"
  local path="${PLUGINS_FOLDER}/${filename}.jar"
  
  echo "Dowloading $source plugin from $url"

  # Download the file to destination folder with the filename
  curl -L -J -s -o "$path" --create-dirs "$url"
  
  final_name=$(get_pluginyml_info "$path" "plugin.yml")
  
  if [[ ! "$final_name" == "" ]]; then
    mv "$path" "${PLUGINS_FOLDER}/${final_name}.jar"
	path="${PLUGINS_FOLDER}/${final_name}.jar"
  fi

  echo "- Downloaded at: $path"
}

# --------------------------------------------------------------------------- #
#              Plugin YAML parser (Obtain plugin name & version)
# --------------------------------------------------------------------------- #

get_pluginyml_info() {
  local jar_path="$1"
  local ymlpath="$2"
  local fallback="$(basename "$jar_path" .jar)"

  tmpdir=$(mktemp -d)

  if [[ -n "$ymlpath" ]]; then
    unzip -qq -d "$tmpdir" "$jar_path" "$ymlpath" 2>/dev/null

    if [[ -f "$tmpdir/$ymlpath" ]]; then
      plugin_yml=$(< "$tmpdir/$ymlpath")

      name=$(echo "$plugin_yml"    | grep -E '^name:'    | sed -E 's/name:[[:space:]]*//')
      version=$(echo "$plugin_yml" | grep -E '^version:' | sed -E 's/version:[[:space:]]*//;s/"//g')

      [[ -z "$name"    ]] && name="$fallback"
      [[ -z "$version" ]] && version="latest"
	  
	  # Remove trailing "\r" to support CL RF format (File saved on Windows)
	  name=$(echo "$name" | tr -d '\r')
	  version=$(echo "$version" | tr -d '\r')

      echo "${name}-${version}"
    fi
  fi

  rm -rf "$tmpdir"
}

# --------------------------------------------------------------------------- #
#                            Plugin file reader
# --------------------------------------------------------------------------- #

mkdir -p "$PLUGINS_FOLDER"

# Read the file to process links
while IFS= read -r line || [ -n "$line" ]; do

  # Remove trailing "\r" to support CL RF format (File saved on Windows)
  line=$(echo "$line" | tr -d '\r')

  # Ignore any empty lines and comments
  if [[ -z "$line" || "$line" =~ ^# ]]; then
    continue
  fi

  # Check link type and call its function
  if [[ "$line" == ${SPIGOT_URL}* ]]; then
    process_spigot_link "$line"
  else
    echo "Invalid link (not Spigot): $line"
  fi
done < "$PLUGIN_FILE"
