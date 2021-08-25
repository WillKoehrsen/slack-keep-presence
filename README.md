# slack-keep-presence

Marks a slack user as active when auto-away kicks in. Useful for keeping slack bots online.

Inspired by [slack-keep-presence](https://github.com/eskerda/slack-keep-presence). This is basically a ruby port with only the presence functionality retained.

## Features

- Uses websockets to connect to Slack's real time api to track presence
- Automatically reconnects if the connection drops and comes back

## Local Installation

* `gem build slack_keep_presence.gemspec`
* `gem install slack_keep_presence-{version}.gem`

## Installation

```bash
gem install slack-keep-presence
```

## Usage

```bash
SLACK_TOKEN=<your_token> slack-keep-presence
```

Or set `SLACK_TOKEN` environment variable beforehand

```bash
slack-keep-presence
```

You can get a token linked to your user at https://api.slack.com/docs/oauth-test-tokens
# slack-keep-presence
