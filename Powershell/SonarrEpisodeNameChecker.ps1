[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter()]
    [bool]
    $renameSeries = $false
)

#------------- DEFINE VARIABLES -------------#

[string]$sonarrApiKey = "9fece972e94d495a9c8a4fcc67b5d41f"
[string]$sonarrUrl = "http://blackbox.lan:8989/sonarr"
[string]$sonarrSeriesStatus = ""

#------------- SCRIPT STARTS -------------#

# Specify location of exclusions file, normally located one directory above the current script location.
$seriesExclusionsFile = Join-Path (Get-Item $PSScriptRoot).Parent -ChildPath excludes\name_excludes.txt
$seriesPathExclusionsFile = Join-Path (Get-Item $PSScriptRoot).Parent -ChildPath \excludes\path_excludes.txt

# Import the contents of the series exclusion list.
if ((Test-Path $seriesExclusionsFile -PathType Leaf) -and (Test-Path $seriesPathExclusionsFile -PathType Leaf)){
    $seriesExclusions = Get-Content $seriesExclusionsFile
    $seriesPathExclusions = Get-Content $seriesPathExclusionsFile
    foreach ($seriesPathExclusion in $seriesPathExclusions){
        if (-Not $seriesPathExclusion.EndsWith("/")){
            throw "$($seriesPathExclusion) does not end in /"
        }
    }
    Write-Output "Exclusions loaded"

}

else {
    throw "Unable to locate exclusions files"
}

# Declare headers that will be passed on each API call.
$webHeaders = @{
    "x-api-key"= "$($sonarrApiKey)"
}

# Retrieve Series Folder Format Config
$namingConfig = Invoke-RestMethod -Uri "$($sonarrUrl)/api/v3/config/naming" -Headers $webHeaders -StatusCodeVariable apiStatusCode | Select-Object -Expand seriesFolderFormat

if ($apiStatusCode -notmatch "2\d\d"){
    throw "Unable to retrieve Series Folder Format from Sonarr"
}

# Replaces illegal characters based on your Series Folder Format from the exclusion list
switch ($namingConfig){
    '{Series TitleYear} {imdb-{ImdbId}}' {
        Write-Output "{Series TitleYear} {imdb-{ImdbId}} detected"
        $seriesExclusions = $seriesExclusions -replace "\(\d\d\d\d\) \{imdb-tt(.*)\}", ""
    }
    '{Series TitleYear} [imdb-{ImdbId}]'{
        Write-Output "{Series TitleYear} [imdb-{ImdbId}] detected"
        $seriesExclusions = $seriesExclusions -replace "\(\d\d\d\d\) \[imdb-tt(.*)\]", ""
    }
    '{Series TitleYear}' {
        Write-Output "{Series TitleYear} detected"
        $seriesExclusions = $seriesExclusions -replace "\(\d\d\d\d\)"
    }
    '{Series TitleYear} [imdb-{ImdbId}][tvdb-{TvdbID}]' {
        Write-Output "{Series TitleYear} [imdb-{ImdbId}][tvdb-{TvdbID}] detected"
        $seriesExclusions = $seriesExclusions -replace "\(\d\d\d\d\) \[imdb-tt(.*)\]\[tvdb-(.*)\]",""
    }
    Default {
        throw "`nYou are not using a supported naming scheme. Supported naming schemes are:`n{Series TitleYear}`n{Series TitleYear} [imdb-{ImdbId}]`n{Series TitleYear} {imdb-{ImdbId}}"
    }
}

# Retrieve all Sonarr series.
$allSeries = Invoke-RestMethod -Uri "$($sonarrUrl)/api/v3/series" -Headers $webHeaders -StatusCodeVariable apiStatusCode

if ($apiStatusCode -notmatch "2\d\d"){
    throw "Unable to retrieve series from Sonarr"
}

else {
    Write-Output "Successfully loaded $($allSeries.count) series from Sonarr"
}

# Filter out series with names that match anything in $seriesExclusions and anything that doesn't match the value of sonarrSeriesStatus
if ($sonarrSeriesStatus -ne ""){
    $filteredSeries = $allSeries | Where-Object {$_.title -notin $seriesExclusions -and $_.rootFolderPath -notin $seriesPathExclusions -and $_.status -eq $($sonarrSeriesStatus)}
}

# Filter out series with names that match anything in $seriesExclusions
else {
    $filteredSeries = $allSeries | Where-Object {$_.title -notin $seriesExclusions -and $_.rootFolderPath -notin $seriesPathExclusions}
}

Write-Output "Series filtering completed, there are now $($filteredSeries.count) series left to process"

# Loop through each object in $filteredSeries.
foreach ($series in $filteredSeries){

    # Query the "rename" endpoint in Sonarr's API to determine if any episodes need to be renamed
    $episodesToRename = Invoke-RestMethod -Uri "$($sonarrUrl)/api/v3/rename?seriesId=$($series.id)" -Headers $webHeaders -StatusCodeVariable apiStatusCode

    # Filter out any episodes that don't have a title of TBA or Episode XX
    $episodesToRename = $episodesToRename | Where-Object {$_.existingPath -cmatch "TBA|Episode [0-9]{1,}"}

    # If the rename endpoint has episodes to be renamed, proceed with refreshing series metadata
    if ($episodesToRename.count -gt 0){

        Write-Output "Starting metadata refresh of $($series.Title)"

        # Send command to Sonarr to refresh the series metadata in case the episode name has changed from what's cached
        $refreshSeries = Invoke-RestMethod -Uri "$($sonarrUrl)/api/v3/command" -Headers $webHeaders -Method Post -ContentType "application/json" -Body "{`"name`":`"RefreshSeries`",`"seriesId`": $($series.id)}" -StatusCodeVariable apiStatusCode

        if ($apiStatusCode -notmatch "2\d\d"){
            throw "Unable to refresh metadata for $($series.title)"
        }

        # Allow Sonarr to finish refreshing the series metadata
        do {
            $tasks = Invoke-RestMethod -Uri "$($sonarrUrl)/api/v3/command" -Headers $webHeaders -Method Get
            $refreshTask = $tasks | Where-Object {$_.id -eq $refreshSeries.id}

            Write-Output "Waiting for metadata refresh for $($series.title) to be finished"
            Start-Sleep 5
        } until (
            $refreshTask.status -eq "completed"
        )

        # If $renameSeries parameter is true, proceed with renaming files
        if ($renameSeries -eq $true){
            Write-Output "Renaming episodes in $($series.title)"

            # If there's only one episode, modify API call to only send the episode
            if ($episodesToRename.count -eq 1){
                $renameFiles = Invoke-RestMethod -Uri "$($sonarrUrl)/api/v3/command" -Headers $webHeaders -Method Post -ContentType "application/json" -Body "{`"name`":`"RenameFiles`",`"seriesId`":$($series.id),`"files`":[$($episodesToRename.episodeFileId)]}" -StatusCodeVariable apiStatusCode
            }

            # If there's more than one episode, modify API call to join all episodes with a ","
            if ($episodesToRename.count -gt 1){
                $renameFiles = Invoke-RestMethod -Uri "$($sonarrUrl)/api/v3/command" -Headers $webHeaders -Method Post -ContentType "application/json" -Body "{`"name`":`"RenameFiles`",`"seriesId`":$($series.id),`"files`":[$($episodesToRename.episodeFileId -join ",")]}" -StatusCodeVariable apiStatusCode
            }

            if ($apiStatusCode -notmatch "2\d\d"){
                throw "Unable to rename episodes for $($series.title)"
            }

        # Allow Sonarr to finish renaming files before moving on to the next series
            do {
                $tasks = Invoke-RestMethod -Uri "$($sonarrUrl)/api/v3/command" -Headers $webHeaders -Method Get
                $renameTask = $tasks | Where-Object {$_.id -eq $renameFiles.id}

                Write-Output "Waiting for files to be renamed for $($series.title)"
                Start-Sleep 5
                } until (
                    $renameTask.status -eq "completed"
                )
        }
        else {
                Write-Output "$($series.title) has episodes to be renamed"
        }
    }

    # If the rename endpoint does not have episodes to be renamed, check files a different way - added in case the series is new and Sonarr has not updated its metadata
    if ($episodesToRename.count -eq 0){
        # Query Sonarr's API using the "$series.id" for a list of existing episodes
        $seriesEpisodes = Invoke-RestMethod -Uri "$($sonarrUrl)/api/v3/episodefile?seriesid=$($series.id)" -Headers $webHeaders

        Write-Output "$($series.title) has $($seriesepisodes.count) episodes"

        # Filter results from previous command to only include episodes with TBA (case sensitive) or Episode XXXX (case sensitive) in their file path.
        $episodesToRename = $seriesEpisodes | Where-Object {$_.relativepath -cmatch "TBA|Episode [0-9]{1,}"}

        Write-Output "$($series.title) with ID $($series.id) has $($episodesToRename.count
        ) episodes to be renamed"

        if ($episodesToRename.count -gt 0){
            Write-Output "Starting metadata refresh of $($series.Title)"

            # Send command to Sonarr to refresh the series metadata in case the episode name has changed from what's cached
            $refreshSeries = Invoke-RestMethod -Uri "$($sonarrUrl)/api/v3/command" -Headers $webHeaders -Method Post -ContentType "application/json" -Body "{`"name`":`"RefreshSeries`",`"seriesId`": $($series.id)}" -StatusCodeVariable apiStatusCode

            if ($apiStatusCode -notmatch "2\d\d"){
                throw "Unable to refresh metadata for $($series.title)"
            }

            # Allow Sonarr to finish refreshing the series metadata
            do {
                $tasks = Invoke-RestMethod -Uri "$($sonarrUrl)/api/v3/command" -Headers $webHeaders -Method Get
                $refreshTask = $tasks | Where-Object {$_.id -eq $refreshSeries.id}

                Write-Output "Waiting for metadata refresh for $($series.title) to be finished"
                Start-Sleep 5
            } until (
                $refreshTask.status -eq "completed"
            )

            # If $renameSeries parameter is true, proceed with renaming files
            if ($renameSeries -eq $true){
                Write-Output "Renaming episodes in $($series.title)"

                # If there's only one episode, modify API call to only send the episode
                if ($episodesToRename.count -eq 1){
                    $renameFiles = Invoke-RestMethod -Uri "$($sonarrUrl)/api/v3/command" -Headers $webHeaders -Method Post -ContentType "application/json" -Body "{`"name`":`"RenameFiles`",`"seriesId`":$($series.id),`"files`":[$($episodesToRename.id)]}" -StatusCodeVariable apiStatusCode
                }

                # If there's more than one episode, modify API call to join all episodes with a ","
                if ($episodesToRename.count -gt 1){
                    $renameFiles = Invoke-RestMethod -Uri "$($sonarrUrl)/api/v3/command" -Headers $webHeaders -Method Post -ContentType "application/json" -Body "{`"name`":`"RenameFiles`",`"seriesId`":$($series.id),`"files`":[$($episodesToRename.id -join ",")]}" -StatusCodeVariable apiStatusCode
                }

                if ($apiStatusCode -notmatch "2\d\d"){
                    throw "Unable to rename episodes for $($series.title)"
                }

            # Allow Sonarr to finish renaming files before moving on to the next series
                do {
                    $tasks = Invoke-RestMethod -Uri "$($sonarrUrl)/api/v3/command" -Headers $webHeaders -Method Get
                    $renameTask = $tasks | Where-Object {$_.id -eq $renameFiles.id}

                    Write-Output "Waiting for files to be renamed for $($series.title)"
                    Start-Sleep 5
                    } until (
                        $renameTask.status -eq "completed"
                    )
            }
            else {
                    Write-Output "$($series.title) has episodes to be renamed"
            }
        }
    }
}
