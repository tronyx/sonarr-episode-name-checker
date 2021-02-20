# Sonarr Episode Name Checker
[![CodeFactor](https://www.codefactor.io/repository/github/tronyx/sonarr-episode-name-checker/badge)](https://www.codefactor.io/repository/github/tronyx/sonarr-episode-name-checker) [![made-with-bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/) [![GitHub](https://img.shields.io/github/license/mashape/apistatus.svg)](https://github.com/tronyx/sonarr-episode-name-checker/blob/master/LICENSE.md)

Script to check for TV Show and Anime episodes that may be named with "Episode ##" or "TBA" that should not be, IE: episode name data was missing or incorrect within Sonarr when the episode was imported.

## Setting it up

1. Clone or download the repo.
2. Properly set your media storage path in the script.
3. Modify the two exclude list text files to meet your needs.
    * If you do not have anything to exclude make sure you blank out the file because they are both required to be there.
4. Determine and set your corresponding column value.
    * Mine is like this: `/mnt/data/media/Videos/TV Shows/Show Name/Season 1/Episode Name`
    * It ends up as column 7 with `/` as the delimiter because `/mnt` is actually the SECOND one and not the first.
5. Set any other variables you would like to set.
    * If `notify` is set to `true`, but you did not set the `webhook` variable the script will prompt you to enter it the first time you run it.

## Scheduling

Now that you have it configured so that everything is working properly, you can use a cronjob to schedule the script to run automatically.

Here's an example of running the script every day at 4am:

```bash
# Run the Sonarr Episode Name Checker script
0 4 * * * /home/tronyx/scripts/SonarrEpisodeNameChecker.sh
```

## Questions

If you have any questions, you can find me on the [Organizr Discord](https://organizr.app/discord).
