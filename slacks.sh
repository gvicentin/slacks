#!/usr/bin/env bash
# slacks.sh
#
#
# Slacks is a command line utility for changing user's profile status in Slack
# on one or more Workspaces at the same time.
#
#
# Version: v0.1.0
# https://github.com/gvicentin/slacks


#===============================================================================
# Constants
#===============================================================================
readonly red=$(tput setaf 1)
readonly green=$(tput setaf 2)
readonly yellow=$(tput setaf 3)
readonly reset=$(tput sgr0)

readonly config_filepath="${HOME}/.slacks.sh"
readonly default_config=$(cat <<EOM
WORKSPACES=[]

PRESET_EMOJI_test=":white_check_mark:"
PRESET_TEXT_test="Testing Slacks"
PRESET_DUR_test="5"
EOM

)


#===============================================================================
# Debug
#===============================================================================
function debug {
    [ "${DEBUG}" = "true" ] && echo "${yellow}[DEBUG] $*${reset}"
}


#===============================================================================
# Config
#===============================================================================
function create_config_if_not_exist {
    [ -f ${config_filepath} ] && return

    # Create default file
    echo -e "${default_config}" > "${config_filepath}"
    echo
    echo "A default configuration has been created at ${green}$CONFIG_FILE.${reset}"

    debug "Config file not found. Creating a new one"
}

function print_config_not_found_and_exit {
    echo "${red}Error: Configuration file doesn't exist${reset}"
    echo "Setup your first Workspace using \`$(basename $0) config\`"
    echo
    echo "For more information, use \`$(basename $0) --help\`"
    exit 1
}

function exec_config {
    echo "${green}Slack Workspace setup${reset}"
    echo "${green}==========================${reset}"
    echo
    echo "You need to have your slack api token ready. If you don't have one,"
    echo "go to https://api.slack.com/apps and create a new application."
    echo "For more information, visit https://github.com/gvicentin/slacks"
    echo
    read -r -p "${green}Enter a name for your workspace: ${reset}" workspace
    read -r -p "${green}Enter the token for ${workspace}: ${reset}" token

    create_config_if_not_exist

    debug "Adding new workspace ${workspace}"

    # Try appending to the end of the list, if list is empty,
    # insert the first item.
    sed -r "s/^WORKSPACES=\[(.+)\]\$/WORKSPACES=\[\1,${workspace}\]/" \
        -i "${config_filepath}"

    sed -r "s/^WORKSPACES=\[\]\$/WORKSPACES=\[${workspace}\]/" \
        -i "${config_filepath}"

    echo "${token}" | keyring set password "slacks-${workspace}"
}


#===============================================================================
# Update status 
#===============================================================================
function get_workspaces {
    echo $(grep 'WORKSPACES' "${config_filepath}" | \
        sed -r 's/^WORKSPACES=\[(.*)\]$/\1/')
}

function print_no_workspaces_and_exit {
    echo "${red}Error: Couldn't find any Workspace configured${reset}"
    echo "Setup your first Workspace using \`$(basename $0) config\`"
    echo
    echo "For more information, use \`$(basename $0) --help\`"
    exit 1
}

function print_set_instructions_and_exit {
    echo "Preset missing"
    echo
    echo "Usage: $(basename $0) PRESET [DURATION]"
    echo
    echo "PRESET        Name of the preset to use"
    echo "DURATION      Status expire duration (Optional)"
    exit 1
}

function change_status_by_workspace {
    local workspace=$1
    local emoji=$2
    local text=$3
    local duration=$4
    debug "$workspace $emoji $text $duration"

    # Get token
    local token=$(keyring get password "slacks-${workspace}")
    debug "Getting token for slacks-${workspace}"
    if [ -z "${token}" ]; then
        echo "${red}Token for ${workspace} not found${reset}"
        return
    fi

    local profile="{\"status_emoji\":\"${emoji}\",\"status_text\":\"${text}\",\"status_expiration\":\"${duration}\"}"
    local response=$(curl -s --data token="${token}" \
        --data-urlencode profile="${profile}" \
        https://slack.com/api/users.profile.set)

    if echo "${response}" | grep -q '"ok":true,'; then
        echo "${green}${workspace}: Status updated ok${reset}"
    else
        echo "${red}There was a problem updating the status${reset}"
        echo "Response: ${response}"
    fi
}

function exec_clean {
    [ -f "${config_filepath}" ] || print_config_not_found_and_exit
     
    local workspaces=$(get_workspaces)
    [ -z "${workspaces}" ] && print_no_workspaces_and_exit

    echo "Resetting slack status to blank"
    for workspace in $(echo ${workspaces} | tr ',' '\n'); do
        change_status_by_workspace "${workspace}" "" "" "0"
    done
}

function exec_set {
    local workspaces=$(get_workspaces)
    local PRESET=$1
    local param_dur=$2
    local EXP="0"
    debug "param dur: ->$param_dur<-"

    # Check for config file, source it to access variables
    [ -f "${config_filepath}" ] || print_config_not_found_and_exit
    source "${config_filepath}"
     
    # Make sure it includes Workspace config
    [ -z "${workspaces}" ] && print_no_workspaces_and_exit

    # Getting preset values
    eval "EMOJI=\$PRESET_EMOJI_${PRESET}"
    eval "TEXT=\$PRESET_TEXT_${PRESET}"
    eval "DUR=\$PRESET_DUR_${PRESET}"
    debug "config duration: ->$DUR<-"

    [ -z $DUR ] && DUR="0"

    if [[ -z $EMOJI || -z $TEXT ]]; then
        echo "${yellow}No preset found:${reset} $PRESET"
        echo
        echo "If this wasn't a typo, then you will want to add the preset to"
        echo "the config file at ${green}${config_filepath} ${reset} and try again."
        exit 1
    fi

    # Overriding duration
    [ -n "$param_dur" ] && DUR=${param_dur}
    debug "Using duration: $DUR"

    # Calculate expiration if needed
    [ "$DUR" != "0" ] && EXP=$(date -d "now + $DUR min" "+%s")
    debug "Using expiration: $EXP"

    if [ "$EXP" == "0" ]; then
        echo "Updating status to: ${yellow}$EMOJI ${green}$TEXT${reset}"
    else
        UNTIL=$(date -d "@$EXP" "+%H:%M")
        echo "Updating status to: ${yellow}$EMOJI ${green}$TEXT until ${yellow}$UNTIL${reset}"
    fi

    for workspace in $(echo ${workspaces} | tr ',' '\n'); do
        change_status_by_workspace "${workspace}" "$EMOJI" "$TEXT" "$EXP"
    done
}


#===============================================================================
# List presets
#===============================================================================
function exec_list {
    [ -f "${config_filepath}" ] || print_config_not_found_and_exit

    local presets=$(grep 'PRESET_TEXT_' "${config_filepath}" | cut -d '=' -f 1)
    echo "${presets}" | sed 's/PRESET_TEXT_//'
}


#===============================================================================
# Options 
#===============================================================================
function exec_help {
    echo "Usage: $(basename $0) COMMAND | [OPTIONS]"
    echo
    echo "Slacks is a command line utility for changing user's profile status"
    echo "in Slack on one or more Workspaces at the same time."
    echo
    echo "COMMANDS:"
    echo "  set             Set current status"
    echo "  clean           Clean current status"
    echo "  config          Add new Workspace configuration"
    echo "  list            List available status presets"
    echo
    echo "OPTIONS:"
    echo "  -h, --help      Print this help message"
    echo "  -v, --version   Print current version"
}

function exec_version {
    grep '^# Version: ' "$0" | cut -d ':' -f 2 | tr -d ' '
}


#===============================================================================
# Main
#===============================================================================
if [ -z "$1" ]; then
    echo "Command or option required"
    echo
    exec_help
    exit 1
fi

while test -n "$1"
do
    case "$1" in

        # Update status
        set) 
            preset=$2
            duration=$3
            shift 2

            # check if don't have preset
            [ -z "$preset" ] && print_set_instructions_and_exit

            exec_set $preset $duration
            ;;

        clean   ) exec_clean ;;

        # Setup new Workspace
        config  ) exec_config ;;

        # Listing presets
        list    ) exec_list ;;

        # Options
        -h | --help     ) exec_help ;;
        -v | --version  ) exec_version ;;

        # Other
        *) 
            echo "Invalid option $1"
            echo
            exec_help
            exit 1
            ;;
    esac

    shift
done
