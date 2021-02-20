# Sonarr Episode Name Checker
[![CodeFactor](https://www.codefactor.io/repository/github/tronyx/sonarr-episode-name-checker/badge)](https://www.codefactor.io/repository/github/tronyx/sonarr-episode-name-checker) [![made-with-bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/) [![GitHub](https://img.shields.io/github/license/mashape/apistatus.svg)](https://github.com/tronyx/sonarr-episode-name-checker/blob/master/LICENSE.md)

Script to check for TV Show and Anime episodes that may be named with "Episode ##" or "TBA" that should not be, IE: episode name data was missing or incorrect within Sonarr when the episode was imported.

## Setting it up

WIP

## Scheduling

Now that you have it configured so that everything is working properly, you can use a cronjob to schedule the script to run automatically.

Here's an example of running the script every day at 4am:

```bash
# Run the Sonarr Episode Name Checker script
0 4 * * * /home/tronyx/scripts/sonarr-episode-name-checker.sh
```

## Questions

If you have any questions, you can find me on the [Organizr Discord](https://organizr.app/discord).
