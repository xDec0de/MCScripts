#!/bin/bash

echo 
echo "           ___   ___   _  __    ___         _                           "
echo "          / __| / __| | |/ /   / __|  ___  | |_   _  _   ____           "
echo "         | (__  \__ \ | ' <    \__ \ / -_) |  _| | || | |  _ \          "
echo "          \___| |___/ |_|\_\   |___/ \___|  \__|  \_,_| | .__/          "
echo "                                                        |_|             "    
echo 

# --------------------------------------------------------------------------- #
#                             Dependency check
# --------------------------------------------------------------------------- #

echo "Checking dependencies..."

if ! command -v java --version >/dev/null 2>&1; then
  echo 
  echo "java is not installed. Please install java and try again."
  echo 
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo 
  echo "jq is not installed. Please install jq and try again."
  echo 
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo 
  echo "curl is not installed. Please install curl and try again."
  echo 
  exit 1
fi

# --------------------------------------------------------------------------- #
#                              Configuration
# --------------------------------------------------------------------------- #

CONFIG_FILE="mcsconfig.env"

# Check if config already exists
if [ -f "$CONFIG_FILE" ]; then
  echo "======================================================================"
  echo " Using existing configuration:"
  echo "----------------------------------------------------------------------"
  cat "$CONFIG_FILE"
  echo "======================================================================"
else
  echo "======================================================================"
  echo " MCScripts Config Generator"
  echo "======================================================================"

  # Function to validate PROJECT
  valid_project() {
    case "$1" in
      paper|folia|velocity|waterfall) return 0 ;;
      *) return 1 ;;
    esac
  }

  # Prompt for PROJECT
  while true; do
    read -p "Project (paper, folia, velocity, waterfall) [paper]: " PROJECT
    PROJECT=${PROJECT:-paper}
    if valid_project "$PROJECT"; then
      break
    else
      echo "Invalid project. Please choose: paper, folia, velocity, or waterfall."
    fi
  done

  # Prompt for VERSION
  read -p "Version (latest or specific version) [latest]: " VERSION
  VERSION=${VERSION:-latest}

  # Function to validate MEMORY
  valid_memory() {
    [[ "$1" =~ ^[0-9]+[MmGg]$ ]]
  }

  # Prompt for MEMORY
  while true; do
    read -p "Memory allocation (e.g., 4G or 512M) [1G]: " MEMORY
    MEMORY=${MEMORY:-1G}
    if valid_memory "$MEMORY"; then
      break
    else
      echo "Invalid memory format. Use number + M or G (e.g., 512M, 2G)."
    fi
  done

  AIKAR_FLAGS="-XX:+AlwaysPreTouch -XX:+DisableExplicitGC -XX:+ParallelRefProcEnabled -XX:+PerfDisableSharedMem -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1HeapRegionSize=8M -XX:G1HeapWastePercent=5 -XX:G1MaxNewSizePercent=40 -XX:G1MixedGCCountTarget=4 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1NewSizePercent=30 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:G1ReservePercent=20 -XX:InitiatingHeapOccupancyPercent=15 -XX:MaxGCPauseMillis=200 -XX:MaxTenuringThreshold=1 -XX:SurvivorRatio=32 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true"

  # Prompt for JVM_FLAGS (optional)
  read -p "Optional JVM Flags (empty or custom, \"aikar\" is replaced with aikar's flags) [empty]: " JVM_INPUT

  # Expand "aikar" if present anywhere in the input (case-insensitive)
  if [[ "${JVM_INPUT,,}" == *aikar* ]]; then
    JVM_FLAGS="${JVM_INPUT//aikar/$AIKAR_FLAGS}"
  else
    JVM_FLAGS="$JVM_INPUT"
  fi

  # Prompt for JAR_FLAGS (optional)
  read -p "Optional JAR Flags (leave empty to skip): " JAR_FLAGS

  # Write to config file
  cat > "$CONFIG_FILE" << EOF
PROJECT=$PROJECT
VERSION=$VERSION
MEMORY=$MEMORY
JVM_FLAGS=$JVM_FLAGS
JAR_FLAGS=$JAR_FLAGS
EOF

  echo ""
  echo "======================================================================"
  echo " Configuration saved to $CONFIG_FILE"
  echo "----------------------------------------------------------------------"
  cat "$CONFIG_FILE"
  echo "======================================================================"
fi

# --------------------------------------------------------------------------- #
#                             Jar download
# --------------------------------------------------------------------------- #

set -a
source $CONFIG_FILE
set +a

if [ -z "$PROJECT" ]; then
  echo "PROJECT not found on $CONFIG_FILE"
  exit 1
fi

if [ ! -f "${PROJECT}.jar" ]; then

  if [ -z "$VERSION" ]; then
    VERSION="latest"
  fi

  USER_AGENT="csk-downloader/1.0"

  if [ "$VERSION" = "latest" ]; then
    VER=$(curl -s -H "User-Agent: $USER_AGENT" https://fill.papermc.io/v3/projects/${PROJECT} | \
    jq -r '.versions | to_entries[0] | .value[0]')
  else
    VER=$VERSION
  fi

  # First check if the version exists
  VERSION_CHECK=$(curl -s -H "User-Agent: $USER_AGENT" https://fill.papermc.io/v3/projects/${PROJECT}/versions/${VER}/builds)

  # Check if the API returned an error
  if echo "$VERSION_CHECK" | jq -e '.ok == false' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$VERSION_CHECK" | jq -r '.message // "Unknown error"')
    echo "Error: $ERROR_MSG"
    exit 1
  fi

  # Get the download URL directly, or null if no stable build exists
  PAPERMC_URL=$(curl -s -H "User-Agent: $USER_AGENT" https://fill.papermc.io/v3/projects/${PROJECT}/versions/${VER}/builds | \
  jq -r 'first(.[] | select(.channel == "STABLE") | .downloads."server:default".url) // "null"')

  if [ "$PAPERMC_URL" != "null" ]; then
    curl -o ${PROJECT}.jar $PAPERMC_URL
  else
    echo "No stable build for version $VER found"
  fi
fi

# --------------------------------------------------------------------------- #
#                               EULA check
# --------------------------------------------------------------------------- #


# EULA check (only for paper and folia)
if [ "$PROJECT" = "paper" ] || [ "$PROJECT" = "folia" ]; then
  if [ ! -f "eula.txt" ]; then
    echo
    echo "The EULA (https://aka.ms/MinecraftEULA) must be accepted to run the server."
    read -p "Do you accept the EULA? (y/n): " ACCEPT_EULA
    if [[ "$ACCEPT_EULA" =~ ^[Yy]$ ]]; then
      echo "eula=true" > eula.txt
      echo "EULA accepted."
    else
      echo "EULA not accepted. Exiting."
      exit 1
    fi
  fi
fi

# --------------------------------------------------------------------------- #
#                             Jar execution
# --------------------------------------------------------------------------- #

echo "Running ${PROJECT} with ${MEMORY} RAM..."
java -Xmx${MEMORY} -Xms${MEMORY} ${JVM_FLAGS} -jar "${PROJECT}.jar" ${JAR_FLAGS}
