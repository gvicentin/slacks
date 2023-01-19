# Slack Status

Slacks is a command line utility for changing user's profile status in Slack on
one or more Workspaces at the same time.

This project is based on the [mivok/slack_status_updater](https://github.com/mivok/slack_status_updater) 
and it aims to improve the previous tool in the following aspects:

- **Token store in the configuration file**: Slack application token is stored
    in plain text in the configuration file so it cannot be versioned.
- **Set status duration**: The ability to set a duration with the status is import
    in my daily activities.
- **Support for multiple Workspaces**: I usually more than one Workspace at work
    and I need to set my status in all of them at the same time.

## Quick start

Create a new Application in Slack:

- Go to [api.slack.com/apps](https://api.slack.com/apps)
- Create a new App, provide a name and select the desired Workspace. You'll 
  need one app for each Workspace
- Navigate to **OAuth & Permission**
- Under **User Token Scopes** add the `users.profile:write` permission
- Click on **Install to Workspace**

Setup *Slacks* CLI tool

```console
git clone https://github.com/gvicentin/slacks.git

# Add it to your PATH
ln -s ~/.local/bin/slacks REPOSITORY_PATH/slacks.sh

# Configure your first Workspace, here you'll provide a name to identify 
# the workspace and the token generated in the step before.
slacks config
```

## Configuration

After running `slacks config` for the first time, you should have a new config
file created at `$HOME/.slacks.conf`. You can include your presets there, for example:

```sh
WORKSPACES=[myworkspace]

PRESET_EMOJI_brb=":brb:"
PRESET_TEXT_brb="Be right back"
PRESET_DUR_brb="30"

PRESET_EMOJI_lunch=":hamburger:"
PRESET_TEXT_lunch="Having lunch"
PRESET_DUR_lunch="60"

PRESET_EMOJI_meeting=":calendar:"
PRESET_TEXT_meeting="Internal meeting"
```

| Setting           | Description                                           |
| ----------------- | ----------------------------------------------------- |
| WORKSPACES        | This is automatically managed by Slacks               |
| PRESET_EMOJI_xxx  | Emoji to be used in the preset                        |
| PRESET_TEXT_xxx   | Status text                                           |
| PRESET_DUR_xxx    | *(Optional)* Duration for expiring status in minutes  |

To update the status using the presets, just use the preset name:

```console
slacks set lunch

# If you need to override the duration
slacks set brb 10
```

## Improvements

- Better `list` option showing the presets as tables, with the text and duration
- New commands to `create`, `update` and `delete` presets from the CLI (don't need
  to use the configuration file)
