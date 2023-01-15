#!/usr/bin/env bash
# slacks.sh
#
#
# Slacks command line utility for changing user's profile status in Slack
# on one or more Workspaces at the same time.
#
#
# Version: v0.1.0
# https://github.com/gvicentin/slacks


#===============================================================================
# Setup
#===============================================================================
set -o errexit
set -o pipefail


#===============================================================================
# Constants
#===============================================================================
readonly __red=$(tput setaf 1)
readonly __green=$(tput setaf 2)
readonly __yellow=$(tput setaf 3)
readonly __reset=$(tput sgr0)

readonly __config_filepath="${HOME}/.slacks.sh"
readonly __default_config=$(cat <<EOM
WORKSPACES=[]

PRESET_EMOJ_test=":white_check_mark:"
PRESET_TEXT_test="Testing Slacks"
PRESET_DURA_test="5"
EOM

)


#===============================================================================
# Functions 
#===============================================================================
function debug {
    [ "$DEBUG" == "true" ] && echo "${__yellow}[DEBUG] $*${__reset}"
}

function create_config_if_not_exist {
    [ -f ${__config_filepath} ] && return

    # Create default file
    debug "Config file not found. Creating a new one"
    echo -e "${__default_config}" > "${__config_filepath}"
}

function exec_config {
    echo "${__green}Slack Workspace setup${__reset}"
    echo "${__green}==========================${__reset}"
    echo
    echo "You need to have your slack api token ready. If you don't have one,"
    echo "go to https://github.com/mivok/slack_status_updater and follow the"
    echo "instructions there for creating a new slack app."
    echo
    read -r -p "${__green}Enter a name for your workspace: ${__reset}" __workspace
    read -r -p "${__green}Enter the token for ${__workspace}: ${__reset}" __token

    # Try appending to the end of the list, if list is empty, 
    # insert the first item.
    create_config_if_not_exist
    debug "Adding new workspace ${__workspace}"
    sed -r "s/^WORKSPACES=\[(.+)\]\$/WORKSPACES=\[\1,${__workspace}\]/" \
        -i "${__config_filepath}"
    sed -r "s/^WORKSPACES=\[\]\$/WORKSPACES=\[${__workspace}\]/" \
        -i "${__config_filepath}"
}

function exec_list {
    local __presets=$(grep 'PRESET_TEXT_' "${__config_filepath}" | cut -d '=' -f 1)
    echo "${__presets}" | sed 's/PRESET_TEXT_//'
}

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
    grep '^# Version: ' slacks.sh | cut -d ':' -f 2 | tr -d ' '
}


#===============================================================================
# Main 
#===============================================================================
if [ -z "$1" ]; then
    echo -e "Command or option required.\n"
    help
    exit 1
fi

while test -n "$1"
do
    case "$1" in

        # Commands
        set     ) exec_set ;;
        clean   ) exec_clean ;;
        config  ) exec_config ;;
        list    ) exec_list ;;

        # Options
        -h | --help     ) exec_help ;;
        -v | --version  ) exec_version ;;
    esac

    shift
done
