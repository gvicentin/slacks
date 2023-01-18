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
readonly RED=$(tput setaf 1)
readonly GREEN=$(tput setaf 2)
readonly YELLOW=$(tput setaf 3)
readonly RESET=$(tput sgr0)

readonly CONFIG_FILE="${HOME}/.slacks.sh"
readonly DEFAULT_CONFIG=$(cat <<EOM
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
    [ "$DEBUG" = "true" ] && echo "${YELLOW}[DEBUG] $*${RESET}"
}


#===============================================================================
# Config
#===============================================================================
function create_config_if_not_exist {
    [ -f "$CONFIG_FILE"} ] && return

    # Create default file
    echo -e "$DEFAULT_CONFIG" > "$CONFIG_FILE"
    echo
    echo "A default configuration has been created at ${GREEN}${CONFIG_FILE}.${RESET}"

    debug "Config file not found. Creating a new one"
}

function print_config_not_found_and_exit {
    echo "${RED}Error: Configuration file doesn't exist${RESET}"
    echo "Setup your first Workspace using \`$(basename $0) config\`"
    echo
    echo "For more information, use \`$(basename $0) --help\`"
    exit 1
}

function exec_config {
    echo "${GREEN}Slack Workspace setup${RESET}"
    echo "${GREEN}==========================${RESET}"
    echo
    echo "You need to have your slack api token ready. If you don't have one,"
    echo "go to https://api.slack.com/apps and create a new application."
    echo "For more information, visit https://github.com/gvicentin/slacks"
    echo
    read -r -p "${GREEN}Enter a name for your workspace: ${RESET}" WORKSPACE 
    read -r -p "${GREEN}Enter the token for ${workspace}: ${RESET}" TOKEN

    create_config_if_not_exist

    debug "Adding new workspace $WORKSPACE"

    # Try appending to the end of the list, if list is empty,
    # insert the first item.
    sed -r "s/^WORKSPACES=\[(.+)\]\$/WORKSPACES=\[\1,${WORKSPACE}\]/" \
        -i "${CONFIG_FILE}"

    sed -r "s/^WORKSPACES=\[\]\$/WORKSPACES=\[${WORKSPACE}\]/" \
        -i "${CONFIG_FILE}"

    echo "${token}" | keyring set password "slacks-${WORKSPACE}"
}


#===============================================================================
# Update status 
#===============================================================================
function get_workspaces {
    echo $(grep 'WORKSPACES' "$CONFIG_FILE" | \
        sed -r 's/^WORKSPACES=\[(.*)\]$/\1/')
}

function print_no_workspaces_and_exit {
    echo "${RED}Error: Couldn't find any Workspace configuRED${RESET}"
    echo "Setup your first Workspace using \`$(basename $0) config\`"
    echo
    echo "For more information, use \`$(basename $0) --help\`"
    exit 1
}

function print_set_instructions_and_exit {
    echo "PRESET missing"
    echo
    echo "Usage: $(basename $0) PRESET [DURATION]"
    echo
    echo "PRESET        Name of the pRESET to use"
    echo "DURATION      Status expire duration (Optional)"
    exit 1
}

function change_status_by_workspace {
    local WORKSPACE=$1
    local EMOJI=$2
    local TEXT=$3
    local DURATION=$4

    # Get token
    local TOKEN=$(keyring get password "slacks-${WORKSPACE}")
    debug "Getting TOKEN for slacks-${WORKSPACE}"
    if [ -z "$TOKEN" ]; then
        echo "${RED}Token for $WORKSPACE not found${RESET}"
        return
    fi

    local profile="{\"status_emoji\":\"${EMOJI}\",\"status_text\":\"${TEXT}\",\"status_expiration\":\"${DURATION}\"}"
    local response=$(curl -s --data token="${TOKEN}" \
        --data-urlencode profile="${profile}" \
        https://slack.com/api/users.profile.set)

    if echo "${response}" | grep -q '"ok":true,'; then
        echo "${GREEN}${WORKSPACE}: Status updated ok${RESET}"
    else
        echo "${RED}There was a problem updating the status for ${WORKSPACE}${RESET}"
        echo "Response: ${response}"
    fi
}

function exec_clean {
    [ -f "$CONFIG_FILE" ] || print_config_not_found_and_exit
     
    local WORKSPACES=$(get_workspaces)
    [ -z "$WORKSPACES" ] && print_no_workspaces_and_exit

    echo "Resetting slack status to blank"
    for workspace in $(echo "$WORKSPACES" | tr ',' '\n'); do
        change_status_by_workspace "${workspace}" "" "" "0"
    done
}

function exec_set {
    local WORKSPACES=""
    local PRESET=$1
    local PARAM_DUR=$2
    local DUR="0"
    local EXP="0"

    # Check for config file, source it to access variables
    [ -f "$CONFIG_FILE" ] || print_config_not_found_and_exit
    source "$CONFIG_FILE"
     
    # Make sure it includes Workspace config
    WORKSPACES=$(get_workspaces)
    [ -z "$WORKSPACES" ] && print_no_workspaces_and_exit

    # Getting pRESET values
    eval "EMOJI=\$PRESET_EMOJI_${PRESET}"
    eval "TEXT=\$PRESET_TEXT_${PRESET}"
    eval "DUR=\$PRESET_DUR_${PRESET}"

    [ -z "$DUR" ] && DUR="0"

    if [[ -z "$EMOJI" || -z "$TEXT" ]]; then
        echo "${YELLOW}No preset found:${RESET} $PRESET"
        echo
        echo "If this wasn't a typo, then you will want to add the pRESET to"
        echo "the config file at ${GREEN}${CONFIG_FILE}${RESET} and try again."
        exit 1
    fi


    # Overriding duration
    [ -n "$PARAM_DUR" ] && DUR="$PARAM_DUR"

    # Calculate expiration if needed
    [ "$DUR" != "0" ] && EXP=$(date -d "now + $DUR min" "+%s")

    if [ "$EXP" == "0" ]; then
        echo "Updating status to: ${YELLOW}${EMOJI} ${GREEN}${TEXT}${RESET}"
    else
        UNTIL=$(date -d "@$EXP" "+%H:%M")
        echo "Updating status to: ${YELLOW}${EMOJI} ${GREEN}${TEXT} until ${YELLOW}${UNTIL}${RESET}"
    fi

    for WORKSPACE in $(echo "$WORKSPACES" | tr ',' '\n'); do
        change_status_by_workspace "$WORKSPACE" "$EMOJI" "$TEXT" "$EXP"
    done
}


#===============================================================================
# List presets
#===============================================================================
function exec_list {
    [ -f "$CONFIG_FILE" ] || print_config_not_found_and_exit

    local PRESETS=$(grep 'PRESET_TEXT_' "$CONFIG_FILE" | cut -d '=' -f 1)
    echo "$PRESETS" | sed 's/PRESET_TEXT_//'
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
    echo "  list            List available status pRESETs"
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
            PRESET=$2
            DURATION=$3
            shift 2

            # check if don't have pRESET
            [ -z "$PRESET" ] && print_set_instructions_and_exit

            exec_set $PRESET $DURATION
            ;;

        clean   ) exec_clean ;;

        # Setup new Workspace
        config  ) exec_config ;;

        # Listing pRESETs
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
