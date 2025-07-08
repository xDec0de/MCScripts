# start.ps1

# Load environment variables from mcsconfig.env
$envFile = ".\mcsconfig.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match "^\s*([^#][^=]+)=(.+)$") {
            Set-Variable -Name $matches[1].Trim() -Value $matches[2].Trim()
        }
    }
} else {
    Write-Error "mcsconfig.env not found"
    exit 1
}

if (-not $PROJECT) {
    Write-Error "PROJECT not found in mcsconfig.env (velocity or paper)"
    exit 1
}

if (-not $VERSION) {
    $VERSION = "latest"
}

$USER_AGENT = "csk-downloader/1.0"
$API_BASE = "https://fill.papermc.io/v3/projects"

$jarFile = "$PROJECT.jar"

if (-not (Test-Path $jarFile)) {

    # Get the version to download
    if ($VERSION -eq "latest") {
        try {
            $response = Invoke-RestMethod -Headers @{ "User-Agent" = $USER_AGENT } -Uri "$API_BASE/$PROJECT"
        } catch {
            Write-Error "Error getting latest version for project $PROJECT"
            exit 1
        }

        # Extract versions keys (major versions)
        $majorVersions = $response.versions.PSObject.Properties.Name

        if (-not $majorVersions -or $majorVersions.Count -eq 0) {
            Write-Error "No versions found for project $PROJECT"
            exit 1
        }

        # Take the first major version key 
        $firstMajorVersion = $majorVersions[0]

        # Take the first specific version inside that major version
        $VER = $response.versions.$firstMajorVersion[0]
    }
    else {
        $VER = $VERSION
    }

    # Check if the version exists and get builds info
    try {
        $builds = Invoke-RestMethod -Headers @{ "User-Agent" = $USER_AGENT } -Uri "$API_BASE/$PROJECT/versions/$VER/builds"
    } catch {
        Write-Error "Error: The specified version ($VER) was not found."
        exit 1
    }

    # $builds is an array, filter stable builds (case-insensitive)
    $stableBuild = $builds | Where-Object { $_.channel -ieq "STABLE" } | Sort-Object -Property id -Descending | Select-Object -First 1

    if (-not $stableBuild) {
        Write-Error "No stable build for version $VER found"
        exit 1
    }

    $downloadUrl = $stableBuild.downloads.'server:default'.url

    if (-not $downloadUrl) {
        Write-Error "No download URL found for the stable build of version $VER"
        exit 1
    }

    # Download the jar
    try {
        Write-Output "Downloading $PROJECT version $VER..."
        Invoke-WebRequest -Headers @{ "User-Agent" = $USER_AGENT } -Uri $downloadUrl -OutFile $jarFile
        Write-Output "Download complete: $jarFile"
    } catch {
        Write-Error "Failed to download $PROJECT jar"
        exit 1
    }
}

# Run jar
Write-Output "Running $PROJECT with $MEMORY RAM..."
java "-Xmx$MEMORY" "-Xms$MEMORY" $JVM_FLAGS -jar $jarFile $JAR_FLAGS
