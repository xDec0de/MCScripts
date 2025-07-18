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

# EULA check (only for paper and folia)
if ($PROJECT -eq "paper" -or $PROJECT -eq "folia") {
    if (-not (Test-Path ".\eula.txt")) {
        Write-Host ""
        Write-Host "The EULA (https://aka.ms/MinecraftEULA) must be accepted to run the server."
        $response = Read-Host "Do you accept the EULA? (y/n)"
        if ($response -match '^[Yy]$') {
            "eula=true" | Out-File -Encoding ASCII -FilePath ".\eula.txt"
            Write-Host "EULA accepted."
        } else {
            Write-Host "EULA not accepted. Exiting."
            exit 1
        }
    }
}

# Split JVM_FLAGS and JAR_FLAGS into arrays if not empty
$jvmFlagsArray = @()
if ($JVM_FLAGS) {
    $jvmFlagsArray = $JVM_FLAGS -split '\s+'
}

$jarFlagsArray = @()
if ($JAR_FLAGS) {
    $jarFlagsArray = $JAR_FLAGS -split '\s+'
}

# Build full argument list
$javaArgs = @("-Xmx$MEMORY", "-Xms$MEMORY") + $jvmFlagsArray + "-jar", $jarFile + $jarFlagsArray

# Run Java
Write-Output "Running $PROJECT with $MEMORY RAM..."
& java @javaArgs
