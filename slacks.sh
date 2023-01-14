#!/usr/bin/env bash

: ' Insert the description of the script here
    # exit(s) status code(s)
    0 - success
    1 - fail
    '

if [ "${DEBUG}" = true ]; then
    # Enable debug mode
    set -x
    export
    whoami
fi

# Setup bash default parameters
set -o errexit
set -o pipefail
set -o nounset

# Check binaries and fail fast
__BASENAME=$(which basename)
__CURL=$(which curl)
__DATE=$(which date)

# Command line arguments
__status=${1-""}
__duration=${2-""}

# Constants
readonly __red=$(tput setaf 1)
readonly __green=$(tput setaf 2)
readonly __yellow=$(tput setaf 3)
readonly __reset=$(tput sgr0)

readonly __config_filepath="${HOME}/.slacks.sh"


function print_usage_and_fail {
    echo "Usage: $0 STATUS [DURATION]"
    echo "To setup new Slack Workspace, use: $0 setup"
    exit 1
}

function create_config_if_not_exist {
    if [ -f ${__config_filepath} ]; then
        return
    fi
    cat > ${__config_filepath} <<EOF
WORKSPACES=

PRESET_EMOJ_test=":white_check_mark:"
PRESET_TEXT_test="Testing status updater"
PRESET_DURA_test="5"
EOF
}

if [ -z ${__status} ]; then
    # Missing status parameter
    print_usage_and_fail
fi

if [ ${__status} == "setup" ]; then
    create_config_if_not_exist

    echo "${__green}Slack Workspace setup${__reset}"
    echo "${__green}==========================${__reset}"
    echo
    echo "You need to have your slack api token ready. If you don't have one,"
    echo "go to https://github.com/mivok/slack_status_updater and follow the"
    echo "instructions there for creating a new slack app."
    echo
    read -r -p "${__green}Enter a name for your workspace: ${__reset}" __workspace
    read -r -p "${__green}Enter the token for ${__workspace}: ${__reset}" __token

    # Try appending to the end of the list
    sed -r "s/^WORKSPACES=(.+)\$/WORKSPACES=\1,${__workspace}/" -i ${__config_filepath}

    # If the list is empty insert the first element
    sed -r "s/^WORKSPACES=\$/WORKSPACES=${__workspace}/" -i ${__config_filepath}
fi
