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

