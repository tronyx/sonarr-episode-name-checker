# Sonarr Episode Name Checker

[![CodeFactor](https://www.codefactor.io/repository/github/tronyx/sonarr-episode-name-checker/badge)](https://www.codefactor.io/repository/github/tronyx/sonarr-episode-name-checker) [![GitHub](https://img.shields.io/github/license/mashape/apistatus.svg)](https://github.com/tronyx/sonarr-episode-name-checker/blob/master/LICENSE.md) ![Shell Script](https://img.shields.io/badge/shell_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white) ![PowerShell](https://img.shields.io/badge/PowerShell-%235391FE.svg?style=for-the-badge&logo=powershell&logoColor=white)

Script to check for TV Show and Anime episodes that may be named with "Episode ##" or "TBA" that should not be, IE: episode name data was missing or incorrect within Sonarr when the episode was imported. Output can be displayed right in the CLI once the script completes:

![Shell Output](/images/shell.png)

![Shell Output - None](/images/shell_none.png)

 And/or a Discord notification can be sent to a custom webhook:

![Discord Webhook](/images/discord.png)

## Setting it up

### Bash

1. Clone or download the repo.
2. Properly set your media storage path in the script.
3. Modify the two exclude list text files to meet your needs.
    * If you do not have anything to exclude make sure you blank out the file because they are both required to be there.
4. Determine and set your corresponding column value.
    * Mine is like this: `/mnt/data/media/Videos/TV Shows/Show Name/Season 1/Episode Name`
    * It ends up as column `7` with `/` as the delimiter because `/mnt` is actually the SECOND one and not the first.
    * For a more visual representation: `(1)/(2)mnt/(3)data/(4)media/(5)Videos/(6)TV Shows/(7)Show Name/`
5. Set any other variables you would like to set.
    * If `notify` is set to `true`, but you did not set the `webhook` variable the script will prompt you to enter it the first time you run it.

> **Warning**
> Depending on your directory structure this might not work for you. It is possible that you might need to put a path, run the script, adjust the path, run the script, etc. to get all your results.
> It can take some trial and error for you to get all of the shows you need/want to exclude as you will want to run the script and then check the shows that are listed for whether or not their episodes are actually named `Episode ##` or not.

### Powershell

> **Note**
> This Powershell script directly interacts with Sonarr's API. It does not support a Discord webhook like the bash script does. Instead we recommend you setup a webhook under `Settings > Connect` and select `Rename` to get Discord notifications when this script runs.

1. Clone or download the repo.
2. Fill in the appropriate variables in `Powershell\SonarrEpisodeNameChecker.ps1`
3. Modify the two exclude list text files to meet your needs.
    * :warning: If you do not have anything to exclude make sure you blank out the files because they are both required to be there.
4. Variables
   1. :warning: **Required** `$sonarrApiKey`: Your Sonarr API Key.
   2. :warning: **Required** `$sonarrUrl`: Your Sonarr URL.
   3. :ballot_box_with_check: **Not required** `$sonarrSeriesStatus`: Accepts any values listed [here](https://github.com/Sonarr/Sonarr/blob/0a2b109a3fe101e260b623d0768240ef8b7a47ae/frontend/src/Components/Filter/Builder/SeriesStatusFilterBuilderRowValue.js#L5-L7).

> **Note**
> It is highly recommended that you do a dry run to see which series might need to be added to your exclusion list!

:whale: Docker image (hopefully) coming soon!

## Scheduling

Now that you have it configured so that everything is working properly, you can use a cronjob to schedule the script to run automatically.

Here's an example of running the script every day at 4am:

### Bash Scheduling

```bash
# Run the Sonarr Episode Name Checker script
0 4 * * * /home/tronyx/scripts/SonarrEpisodeNameChecker.sh
```

### Powershell Scheduling

```powershell
# Run the Sonarr Episode Name Checker script
0 4 * * * /home/tronyx/scripts/Powershell/SonarrEpisodeNameChecker.ps1 -renameSeries $true
```

## Questions

If you have any questions, you can find me on the [Organizr Discord](https://organizr.app/discord).
