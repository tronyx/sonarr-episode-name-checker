$webHeaders = @{
    "x-api-key"=""
}
$allSeries = Invoke-RestMethod -Uri -Headers $webHeaders -StatusCodeVariable apiStatusCode


if ($apiStatusCode -notmatch "2\d\d"){
    throw "Unable to retrieve series from Sonarr"
}

else {
    Write-Verbose "Retrieved $($allseries.count) series from Sonarr"
}

$allSeriesWithEpisodes = $allSeries | Where-Object {$_.statistics.episodefilecount -gt 0} | Sort-Object title

foreach ($series in $allSeriesWithEpisodes){

    $seriesEpisodes = Invoke-RestMethod -Uri -Headers $webHeaders | Where-Object {$_.hasfile -eq $true}

    foreach ($seriesEpisode in $seriesEpisodes){

    $episodePath = Invoke-RestMethod -Uri -Headers $webHeaders | Select-Object -Expand path

    Write-Host $episodePath

    if ($episodePath -match "TBA|Episode [0-9]{1,}"){
        Write-Host "$($series.title) has episodes with TBA or Episodes in its filename"
    }

    }
}
