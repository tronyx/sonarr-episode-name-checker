[CmdletBinding(SupportsShouldProcess)]
param (
)

$timer = [System.Diagnostics.Stopwatch]::StartNew()

# Function to read config file.
function Read-IniFile {
    param (
        $file
    )

    $ini = @{}

    # Create a default section if none exist in the file. Like a java prop file.
    $section = "NO_SECTION"
    $ini[$section] = @{}

    switch -regex -file $file {
        "^\[(.+)\]$" {
            $section = $matches[1].Trim()
            $ini[$section] = @{}
        }
        "^\s*([^#].+?)\s*=\s*(.*)" {
            $name,$value = $matches[1..2]
            # skip comments that start with semicolon:
            if (!($name.StartsWith(";"))) {
                $ini[$section][$name] = $value.Trim()
            }
        }
    }
    $ini
}

# Specify location of config file, normally located in the same directory as the script.
$configFile = Join-Path -Path $PSScriptRoot -ChildPath SonarrEpisodeNameChecker.conf
Write-Verbose "Location for config file is $configFile"

# Read the parameters from the config file.
if (Test-Path  $configFile -PathType Leaf){
    $config = Read-IniFile -File $configFile
    Write-Verbose "Config file parsed"
}

else {
    throw "Unable to locate config file"
}

# Specify location of exclusions file, normally located one directory above the current script.
$seriesExclusionsFile = Join-Path (Get-Item $PSScriptRoot).Parent -ChildPath excludes\name_excludes.txt

# Import the contents of the series exclusion list.
if (Test-Path $seriesExclusionsFile -PathType Leaf){
    $seriesExclusions = Get-Content $seriesExclusionsFile
    Write-Verbose "Exclusions loaded"
}

else {
    throw "Unable to locate exclusions file"
}

# Declare headers that will be passed on each API call.
$webHeaders = @{
    "x-api-key"= "$($config.Sonarr.sonarrApiKey)"
}

# Retrieve all Sonarr series.
$allSeries = Invoke-RestMethod -Uri "$($config.Sonarr.sonarrURL)/api/v3/series" -Headers $webHeaders -StatusCodeVariable apiStatusCode

if ($apiStatusCode -notmatch "2\d\d"){
    throw "Unable to retrieve series from Sonarr"
}

else {
    Write-Verbose "Successfully loaded $($allSeries.count) series from Sonarr"
}

# Filter series with names that match anything in $seriesExclusions and anything that doesn't match the value of sonarrSeriesStatus in the config file.
$filteredSeries = $allSeries | Where-Object {$_.title -notin $seriesExclusions -and $_.status -eq $($config.Sonarr.sonarrSeriesStatus)}

Write-Verbose "Series filtering completed, there are now $($filteredSeries.count) series left to process"

# Loop through each $series object in $filteredSeries.
foreach ($series in $filteredSeries){

    # Query API for a list of existing episodes matching the series loaded from $filteredSeries by specifying the series ID.
    $seriesEpisodes = Invoke-RestMethod -Uri "$($config.Sonarr.sonarrURL)/api/v3/episodefile?seriesid=$($series.id)" -Headers $webHeaders

    # Filter results from previous command to only include episodes with TBA (case sensitive) or Episode XXXX (case sensitive) in their file path.
    $episodesToRename = $seriesEpisodes | Where-Object {$_.relativepath -cmatch "TBA|Episode [0-9]{1,}"}

    # Grab series ID from episodes filtered and if there are multiple episodes for the same series, only grab the ID once.
    $seriesIdsToRefresh = $episodesToRename | Select-Object -ExpandProperty seriesId -Unique

    # Loop through each $seriesIdToRefresh object in $seriesIdsToRefresh
    foreach ($seriesIdToRefresh in $seriesIdsToRefresh){

        # Grab the series object from $filteredSeries that matches the ID
        $series = $filteredSeries | Where-Object {$_.id -eq $seriesIdToRefresh}

        Write-Verbose "Starting metadata refresh of $($series.Title)"

        # Send command to Sonarr to refresh the series metadata
        $refreshSeries = Invoke-RestMethod -Uri "$($config.Sonarr.sonarrURL)/api/v3/command" -Headers $webHeaders -Method Post -ContentType "application/json" -Body "{`"name`":`"RefreshSeries`",`"seriesId`": $($seriesIdToRefresh)}" -StatusCodeVariable apiStatusCode

        if ($apiStatusCode -notmatch "2\d\d"){
            throw "Unable to refresh metadata for $($series.title)"
        }

        Start-Sleep -Seconds 5 -Verbose
    }

    foreach ($episode in $episodesToRename){

        $renameSeries = Invoke-RestMethod -Uri "$($config.Sonarr.sonarrURL)/api/v3/command" -Headers $webHeaders -Method Post -ContentType "application/json" -Body "{`"name`":`"RenameFiles`",`"seriesId`":$($episode.seriesId),`"files`":[$($episode.Id)]}" -StatusCodeVariable apiStatusCode

        if ($apiStatusCode -notmatch "2\d\d"){
            throw "Unable to rename episodes for $($series.title)"
        }
    }
}

$timer.Stop()
$timer.ElapsedMilliseconds
