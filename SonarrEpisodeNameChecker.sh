#!/usr/bin/env bash
#
# Find unnamed TV Show episodes that have "TBA" or "Episode ##" as the title
# Tronyx

# Define some variables
# Path to parent dir for all media
mediaPath='/mnt/data/media/Videos'
# List of shows you want to be excluded
nameExclusionList='excludes/name_excludes.txt'
# List of paths you want to be excluded
pathExclusionList='excludes/path_excludes.txt'
# Column number to use with the awk command in the find_shows function
# You may need to adjust this value depending on the number of columns in the full path to the show name
# For example, my path to an episode is "/mnt/data/media/Videos/TV Shows/Show Name/Season 1/Episode Name" which ends up being 7
column=7
# Whether or not you want to display output on the CLI
cliDisplay='true'
# Whether or not you want to send a notification to Discord
notify='true'
# Send a notification even when no shows are found.
notifyAll='false'
# Discord webhook URL
webhookUrl=''
# CLI font colors
readonly red='\e[31m'
readonly endColor='\e[0m'

## Notes
## Path exclusion file should look like this, with the FULL path (No # at the beginning of the line):
#/mnt/data/media/Videos/HD Movies/
#/mnt/data/media/Videos/Movies/
#/mnt/data/media/Videos/Anime/Naruto Shippuuden/Season 13/

## Name exclusion file should look like this with the FULL directory name for the show or movie (No # at the beginning of the line):
#Alice in Borderland (2020)
#Drunk History (UK)
#Ripley's Believe It or Not! (2000)
## You will need to narrow down which shows to include/exclude based on whether or not the Series actually uses "Episode ##" for the episode titles.

# Function to gather script information.
get_scriptname() {
    local source
    local dir
    source="${BASH_SOURCE[0]}"

    while [[ -L ${source} ]]; do
        dir="$(cd -P "$(dirname "${source}")" > /dev/null && pwd)"
        source="$(readlink "${source}")"
        [[ ${source} != /* ]] && source="${dir}/${source}"
    done

    echo "${source}"
}

readonly scriptname="$(get_scriptname)"

# Function to grab line numbers of the user-defined and status variables.
get_line_numbers() {
    webhookUrlLineNum=$(head -25 "${scriptname}" | grep -En -A1 'Discord webhook' | tail -1 | awk -F- '{print $1}')
}

# Function to check that the webhook URL is defined if alert is set to true.
# If alert is set to true and the URL is not defined, prompt the user to provide it.
check_webhook_url() {
    if [[ ${webhookUrl} == '' ]] && [[ ${notify} == 'true' ]]; then
        echo -e "${red}You didn't define your Discord webhook URL!${endColor}"
        echo ''
        echo 'Enter your webhook URL:'
        read -r url
        echo ''
        echo ''
        sed -i "${webhookUrlLineNum} s|webhookUrl='[^']*'|webhookUrl='${url}'|" "${scriptname}"
        webhookUrl="${url}"
    fi
}

# Function to find list of shows with incorrect names.
find_shows() {
    showsFile=$(mktemp)
    find "${mediaPath}" -type f \( -name "* - Episode*" -o -name "*TBA*" \) | grep -v partial | grep -v -f "${pathExclusionList}" | grep -v -f "${nameExclusionList}" | awk -F/ -v col="${column}" '{print $col}' | uniq > "${showsFile}"
}

# Function to determine the number of results to then determine whether or not what output to display.
show_count() {
    showCount=$(wc -l "${showsFile}" | awk '{print $1}')
}

# Function to display the output
display_output() {
    if [[ ${showCount} -gt '0' ]]; then
        echo 'The following shows have episodes named "Episode ##" or "TBA":'
        echo ''
        cat "${showsFile}"
        echo ''
        echo "You should perform a Refresh & Scan on these shows in Sonarr and then rename them if they've updated with the correct name."
        echo ''
    elif [[ ${showCount} -eq '0' ]]; then
        echo 'No shows found with episodes named "Episode ##" or "TBA".'
        echo ''
    fi
}

# Function to send Discord notifications.
send_notification() {
    if [[ -f ${showsFile} ]]; then
        badShows=$(awk '{print}' ORS='\\n' "${showsFile}")
        if [[ ${notifyAll} == 'true' ]]; then
            if [[ ${showCount} -gt '0' ]]; then
                curl -s -H "Content-Type: application/json" -X POST -d '{"embeds": [{"title": "The following shows have episodes named Episode ## or TBA:", "description": "'"${badShows}"'\n**You should perform a Refresh & Scan on these shows in Sonarr and then rename them if they have updated with the correct name.**", "color": 16711680}]}' "${webhookUrl}"
            elif [[ ${showCount} -eq '0' ]]; then
                curl -s -H "Content-Type: application/json" -X POST -d '{"embeds": [{"description": "**No shows found with episodes named Episode ## or TBA.**","color": 39219}]}' "${webhookUrl}"
            fi
        elif [[ ${notifyAll} == 'false' ]]; then
            if [[ ${showCount} -gt '0' ]]; then
                curl -s -H "Content-Type: application/json" -X POST -d '{"embeds": [{"title": "The following shows have episodes named Episode ## or TBA:", "description": "'"${badShows}"'\n**You should perform a Refresh & Scan on these shows in Sonarr and then rename them if they have updated with the correct name.**", "color": 16711680}]}' "${webhookUrl}"
            fi
        fi
    fi
}

# Main function to run all other functions.
main() {
    get_scriptname
    get_line_numbers
    check_webhook_url
    find_shows
    show_count
    if [[ ${cliDisplay} == 'true' ]]; then
        display_output
    fi
    if [[ ${notify} == 'true' ]]; then
        send_notification
    fi
}

main
