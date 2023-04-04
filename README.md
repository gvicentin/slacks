# Slack Status

![Latest Release](https://img.shields.io/github/v/release/gvicentin/slacks)
![License](https://img.shields.io/github/license/gvicentin/slacks)

Slacks is a command line utility for changing user profile status in Slack on
one or more Workspaces at the same time.

This project is based on the [mivok/slack_status_updater](https://github.com/mivok/slack_status_updater) 
and it aims to improve the previous tool in the following aspects:

- **Support for multiple Workspaces**: I usually have more than one Workspace at work
    and I need to update my status in all of them at the same time.
- **Set status duration**: The ability to set a duration with the status is import
    in my daily activities.
- **Do not Disturb**: Pause notifications is very helpful when you need to do a focused
    session.
- **Token stored using keyring**: Slack application token is now stored using keyring
    for safety.

## Quick start

### Create a new Application in Slack:

- Visit the following URL: [api.slack.com/apps](https://api.slack.com/apps).
- Click on *Create New App* on the top right corner.
- Select the option *From scratch*.
- Choose a name and the workspace you want to install the app.
- After creating the app, navigate to **OAuth & Permission** using the left menu.
- Under **User Token Scopes** add the followind scope permission.
    - `users.profile:write`
    - `dnd:write`
- Using the left menu, select the *Basic Information* option.
- Under **Install you app** click on *Install*.
- Copy the generated token. This will be configured in the CLI later.

### Setup *Slacks* CLI tool

After cloning the repository and adding the script to you `$PATH` variable. You can run
the following command to setup your first Workspace.

```console
# Provide the following information:
#   - `WORKSPACE_NAME`: Can be anything.
#   - `APP_TOKEN`: Token generated after creating app using https://api.slack.com/apps
slacks workspace add

Enter a name for your workspace: WORKSPACE_NAME
Enter the token for : APP_TOKEN
```

### Changing the status

For setting your status using custom parameters using the `set` command.

```console
# Set the status with a custom message and emoji with 5 minutes
# of duration.
slacks set --status "My status" --emoji ":bomb:" --duration 5

# Use the --dnd flag to pause notifications while the status
# is active.
slacks set --status "My focused status" --dnd

# Use --help command to see all the available options
slacks set --help
```

| Parameter | Description | Default |
|-----------|-------------|---------|
|`--status` | (Required) Status message | `None` |
|`--emoji`  | (Optional) Status message emoji | `:speech_balloon:` |
|`--duration` | (Optional) Status duration in minutes. Value `0` means don't expire | `0` |
|`--dnd` | (Optional) Enable Do not Disturb. This will pause the notifications as long as the status is active | `None` |

## Configuration

### Presets

You can create and configure **presets** to quickly change the status. See the following
example to create a new preset.

```console
# Creating a new preset called `meeting`
slacks preset add

Enter a name for your status: meeting
Enter a status text: Internal meeting
Enter a status emoji. (Enter for default): :calendar:
Enter a duration in minutes. (Enter for not expiring):
Enable Do not Disturb? [y/N]: y

# Listing all presets
slacks preset list
PRESET               TEXT                           DURATION        DnD
brb                  Be right back                  30              false
lunch                Having lunch                   60              false
meeting              Internal meeting               No expiring     true

# See all the options using the `--help` flag.
slacks preset --help
```

See an [example bellow](#useful-presets) for some useful presets.

### Workspaces

You can add and edit your Workspaces using the CLI. Your status will be updated
automatically on every workspace you have configured.

```console
# Add a new Workspace. We need to have a generated token for each workspace
slacks workspace add

# For all the workspace commands, use the --help flag.
slacks workspace --help
```

### Useful presets

After running `slacks workspace add` for the first time, you should have a new config
file created at `$HOME/.slacks.conf`. You can include your presets there, for example:

```sh
# Leave this line, it's handle automatically by Slacks.
WORKSPACES=[myworkspace]

# Append this presets to your config file
PRESET_EMOJI_brb=":brb:"
PRESET_TEXT_brb="Be right back"
PRESET_DUR_brb="30"

PRESET_EMOJI_lunch=":hamburger:"
PRESET_TEXT_lunch="Having lunch"
PRESET_DUR_lunch="60"

PRESET_EMOJI_meeting=":calendar:"
PRESET_TEXT_meeting="Internal meeting"
PRESET_DNR_meeting="true"

PRESET_EMOJI_focus=":floppy_disk:"
PRESET_TEXT_focus="Focused session"
PRESET_DUR_focus="60"
PRESET_DNR_focus="true"
```

Config file settings:

| Setting           | Description                                           |
| ----------------- | ----------------------------------------------------- |
| WORKSPACES        | This is automatically managed by Slacks               |
| PRESET_EMOJI_xxx  | Emoji to be used in the preset                        |
| PRESET_TEXT_xxx   | Status text                                           |
| PRESET_DUR_xxx    | *(Optional)* Duration for expiring status in minutes  |
| PRESET_DND_xxx    | *(Optional)* Enable Do not Disturb                    |
