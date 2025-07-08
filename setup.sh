#!/bin/bash

set -a
source mcsconfig.env
set +a

if [ -z "$PROJECT" ]; then
  echo "PROJECT not found on mcsconfig.env (velocity or paper)"
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

# Run jar
echo "Running ${PROJECT} with ${MEMORY} RAM..."
java -Xmx${MEMORY} -Xms${MEMORY} ${JVM_FLAGS} -jar "${PROJECT}.jar" ${JAR_FLAGS}
