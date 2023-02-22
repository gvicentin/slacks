#!/usr/bin/env bash
# slacks.sh
#
#
# Slacks is a command line utility for changing user's profile status in Slack
# on one or more Workspaces at the same time.
#
#
# Version: v0.2.0
# https://github.com/gvicentin/slacks


#---------------------------------[ Constants ]---------------------------------
readonly RED=$(tput setaf 1)
readonly GREEN=$(tput setaf 2)
readonly YELLOW=$(tput setaf 3)
readonly RESET=$(tput sgr0)

readonly CONFIG_FILE="${HOME}/.slacks.conf"
readonly DEFAULT_CONFIG=$(cat <<EOM
WORKSPACES=[]

PRESET_EMOJI_test=":white_check_mark:"
PRESET_TEXT_test="Testing Slacks"
PRESET_DUR_test="5"
EOM

)

#-----------------------------------[ Utils ]-----------------------------------
function debug {
    [ "$DEBUG" = "true" ] && echo "${YELLOW}[DEBUG] $*${RESET}"
}

function create_config_if_not_exist {
    [ -f "$CONFIG_FILE" ] && return

    # Create default file
    echo -e "$DEFAULT_CONFIG" > "$CONFIG_FILE"
    echo
    echo "A default configuration has been created at ${GREEN}${CONFIG_FILE}${RESET}"

    debug "Config file not found. Creating a new one"
}

function print_config_not_found_and_exit {
    echo "${RED}Error: Configuration file doesn't exist${RESET}"
    echo "Setup your first Workspace using \`$(basename $0) config\`"
    echo
    echo "For more information, use \`$(basename $0) --help\`"
    exit 1
}

function print_invalid_cmd_and_exit {
    local ERROR_MSG="$1"
    local HELP="$2"

    # print error, help
    echo -e "${RED}${ERROR_MSG}${RESET}\n" 
    echo -e "$HELP"

    exit 1
}

function get_workspaces {
    echo $(grep 'WORKSPACES' "$CONFIG_FILE" | sed -r 's/^WORKSPACES=\[(.*)\]$/\1/')
}

function print_no_workspaces_and_exit {
    echo "${RED}Error: Couldn't find any Workspace configured${RESET}"
    echo "Setup your first Workspace using \`$(basename $0) config\`"
    echo
    echo "For more information, use \`$(basename $0) --help\`"
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

    local PROFILE="{\"status_emoji\":\"${EMOJI}\",\"status_text\":\"${TEXT}\",\"status_expiration\":\"${DURATION}\"}"

    debug "Sending request: $PROFILE"

    local RESPONSE=$(curl -s --data token="${TOKEN}" \
        --data-urlencode profile="${PROFILE}" \
        https://slack.com/api/users.profile.set)

    if echo "${RESPONSE}" | grep -q '"ok":true,'; then
        echo "${GREEN}${WORKSPACE}: Status updated ok${RESET}"
    else
        echo "${RED}There was a problem updating the status for ${WORKSPACE}${RESET}"
        echo "Response: ${RESPONSE}"
    fi
}

#---------------------------------[ Workspace ]---------------------------------
function exec_workspace_list {
    [ -f "$CONFIG_FILE" ] || print_config_not_found_and_exit
    source $CONFIG_FILE

    local WORKSPACE_WIDTH=20
    local WORKSPACES=$(get_workspaces | tr ',' ' ')

    if [ -z "$WORKSPACES" ]; then
        # don't have any preset yet
        echo "You don't have any workspace yet"
        return
    fi

    # print header
    printf "%-*s\n" $WORKSPACE_WIDTH "WORKSPACE"

    for WORKSPACE in $WORKSPACES; do
        # print rows
        printf "%-*s\n" $WORKSPACE_WIDTH "$WORKSPACE"
    done

    exit 0
}

function exec_workspace_add {
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

    debug "Saving token in keyring named slacks=${WORKSPACE}"

    echo "${TOKEN}" | keyring set password "slacks-${WORKSPACE}"

    exit 0
}

function exec_workspace_remove {
    [ -f "$CONFIG_FILE" ] || print_config_not_found_and_exit

    local WORKSPACES=$(get_workspaces)
    local IS_VALID="false"

    read -r -p "Select workspace to remove (${WORKSPACES}): " REM_WORKSPACE 

    for WORKSPACE in $(echo $WORKSPACES | tr ',' ' '); do
        test "$WORKSPACE" = "$REM_WORKSPACE" && IS_VALID="true"
    done

    if [ "$IS_VALID" = "false" ]; then
        echo "${RED}Invalid workspace provided: ${REM_WORKSPACE}${RESET}"
        exit 1
    fi

    # remove entry from config file
    WORKSPACES=$(echo $WORKSPACES | sed -r "s/${REM_WORKSPACE},|,${REM_WORKSPACE}//")
    sed -r "s/^WORKSPACES=\[.*\]\$/WORKSPACES=\[${WORKSPACES}\]/" \
        -i "${CONFIG_FILE}"

    # remove token
    keyring del password "slacks-${REM_WORKSPACE}"

    echo "${GREEN}Workspace $REM_WORKSPACE removed.${RESET}"
    exit 0
}

function exec_workspace_help {
    echo "Usage: $(basename $0) workspace [COMMAND|OPTIONS]"
    echo
    echo "Control your workspaces. You can update your status in multiples"
    echo "workspaces at the same time."
    echo
    echo "COMMANDS:"
    echo "  list            List your workspaces"
    echo "  add             Configure a new workspace"
    echo "  remove          Removes workspace configuration"
    echo
    echo "OPTIONS:"
    echo "  -h, --help      Print this help message"

    exit 0
}

function exec_workspace {
    if [ -z "$1" ]; then
        print_invalid_cmd_and_exit "Command or option required." \
                                   "$(exec_workspace_help)"
    fi

    while [ -n "$1" ]; do
        case "$1" in
            # commands
            list   ) exec_workspace_list   ;;
            add    ) exec_workspace_add    ;;
            remove ) exec_workspace_remove ;;

            # options
            -h | --help ) exec_workspace_help ;;

            # other
            *) print_invalid_cmd_and_exit "Invalid option $1" \
                                          "$(exec_workspace_help)" ;;
        esac
        shift
    done

    exit 0
}

#-----------------------------------[ Clean ]-----------------------------------
function exec_clean {
    [ -f "$CONFIG_FILE" ] || print_config_not_found_and_exit
     
    local WORKSPACES=$(get_workspaces)
    [ -z "$WORKSPACES" ] && print_no_workspaces_and_exit

    echo "Resetting slack status to blank"
    for workspace in $(echo "$WORKSPACES" | tr ',' '\n'); do
        change_status_by_workspace "${workspace}" "" "" "0"
    done
}

#----------------------------------[ Preset ]-----------------------------------
function exec_preset_use {
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

    # Getting preset values
    eval "EMOJI=\$PRESET_EMOJI_${PRESET}"
    eval "TEXT=\$PRESET_TEXT_${PRESET}"
    eval "DUR=\$PRESET_DUR_${PRESET}"

    [ -z "$DUR" ] && DUR="0"

    if [[ -z "$EMOJI" || -z "$TEXT" ]]; then
        echo "${YELLOW}No preset found:${RESET} $PRESET"
        echo
        echo "If this wasn't a typo, then you will want to add the preset to"
        echo "the config file at ${GREEN}${CONFIG_FILE}${RESET} and try again."
        exit 1
    fi

    # Overriding duration
    if [ -n "$PARAM_DUR" ]; then 
        debug "Overriding duration with $PARAM_DUR"
        DUR="$PARAM_DUR"
    fi

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

    exit 0
}

function exec_preset_list {
    [ -f "$CONFIG_FILE" ] || print_config_not_found_and_exit
    source $CONFIG_FILE

    # column dimension
    local PRESET_WIDTH=20
    local TEXT_WIDTH=30
    local DURATION_WIDTH=15

    local PRESETS=$(grep -Eo 'PRESET_TEXT_[^=]+' $CONFIG_FILE | sed 's/PRESET_TEXT_//')

    if [ -z "$PRESETS" ]; then
        # don't have any preset yet
        echo "You don't have any preset yet"
        echo "Add new presets using the config file: ${GREEN}${CONFIG_FILE}${RESET}"
        return
    fi

    # print header
    printf "%-*s %-*s %-*s\n" $PRESET_WIDTH "PRESET" \
                              $TEXT_WIDTH "TEXT" \
                              $DURATION_WIDTH "DURATION"

    for PRESET in $PRESETS; do
        eval "TEXT=\$PRESET_TEXT_${PRESET}"
        eval "DURATION=\$PRESET_DUR_${PRESET}"

        test -z "$TEXT" && TEXT="None"
        test -z "$DURATION" && DURATION="No expiring"

        # print row
        printf "%-*s %-*s %-*s\n" $PRESET_WIDTH "$PRESET" \
                                  $TEXT_WIDTH "$TEXT" \
                                  $DURATION_WIDTH "$DURATION"
    done

    exit 0
}

function exec_preset_help {
    echo "Usage: $(basename $0) preset [COMMAND|OPTIONS]"
    echo
    echo "Update your status using a preset. You can configure presets and"
    echo "use them to save time."
    echo
    echo "COMMANDS:"
    echo "  use             Use preset"
    echo "  list            List your presets"
    echo "  add             Configure new preset" 
    echo "  remove          Removes a preset"
    echo
    echo "OPTIONS:"
    echo "  -h, --help      Print this help message"

    exit 0
}

function exec_preset {
    if [ -z "$1" ]; then
        print_invalid_cmd_and_exit "Command or option required." \
                                   "$(exec_preset_help)"
    fi

    while [ -n "$1" ]; do
        case "$1" in
            # commands
            use    ) exec_preset_use "${@:2}" ;;
            list   ) exec_preset_list         ;;
            add    ) exec_preset_add          ;;
            remove ) exec_preset_remove       ;;

            # options
            -h | --help ) exec_preset_help ;;

            # other
            *) print_invalid_cmd_and_exit "Invalid command '$1'" \
                                          "$(exec_preset_help)" ;; 
        esac
        shift
    done

    exit 0
}

#-----------------------------[ Help and Version ]------------------------------
function exec_help {
    echo "Usage: $(basename $0) [COMMAND|OPTIONS]"
    echo
    echo "Slacks is a command line utility for changing user's profile status"
    echo "in Slack on one or more Workspaces at the same time."
    echo
    echo "Some commands support the --help (or -h) option for more information:"
    echo "$(basename $0) COMMAND --help"
    echo
    echo "COMMANDS:"
    echo "  workspace       Configure your slack's workspaces"
    echo "  set             Update your status with custom parameters"
    echo "  preset          Configure and re-use presets for your status"
    echo "  clean           Remove current status if there is any"
    echo
    echo "OPTIONS:"
    echo "  -h, --help      Print this help message"
    echo "  -v, --version   Print current version"
}

function exec_version {
    grep '^# Version: ' "$0" | cut -d ':' -f 2 | tr -d ' '
}

#-----------------------------------[ Main ]------------------------------------
if [ -z "$1" ]; then
    print_invalid_cmd_and_exit "Command or option required." \
                               "$(exec_help)"
fi

while [ -n "$1" ]; do
    case "$1" in
        # commands
        workspace ) exec_workspace "${@:2}" ;;
        set       ) exec_set       "${@:2}" ;;
        preset    ) exec_preset    "${@:2}" ;;
        clean     ) exec_clean              ;;

        # options
        -h | --help    ) exec_help     ;;
        -v | --version ) exec_version  ;;

        # other
        *) print_invalid_cmd_and_exit "Invalid option $1" \
                                      "$(exec_help)" ;;
    esac
    shift
done
