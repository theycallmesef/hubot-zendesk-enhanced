# hubot-zendesk

Allows hubot to query and update Zendesk support tickets.

See [`src/zendesk-enhanced.coffee`](src/zendesk-enhanced.coffee) for full documentation.

## Installation

In hubot project repo, run:

`npm install hubot-zendesk-enhanced --save`

Then add **hubot-zendesk-enhanced** to your `external-scripts.json`:

```json
["hubot-zendesk-enhanced"]
```

# Configuration:
```
HUBOT_ZENDESK_USER - (required)
HUBOT_ZENDESK_PASSWORD - (required)
HUBOT_ZENDESK_SUBDOMAIN - (required) subdomain for your Zendesk group. (http://<subdomain>.zendesk.com/)
HUBOT_ZENDESK_HEAR - (optional) If present, activates responses without being address directly.
HUBOT_ZENDESK_EMOJI - (optional) Appends text for emoji icon to responses. (ex: :zendesk:)
HUBOT_ZENDESK_GROUP - (optional) Limits default searches to a group (name or ID #) or groups (comma separated).
HUBOT_ZENDESK_ADAPTER - (optional) Appends provided adapter name to comments. Defaults to 'Hubot'.
HUBOT_ZENDESK_DISABLE_UPDATE - (optional) If present, disables hubot's ability to update tickets.
```

# Commands:
```
General Help:
hubot zendesk help - Will list available commands
hubot zendesk group help - Will list available commands for 'group'
hubot zendesk update help - Will list available commands for 'update'

General Commands:
hubot zendesk ticket <ID> - Returns information about the specified ticket.
hubot zendesk list <all|status|tag> tickets <group>(optional) - returns a count of tickets with the status (all=unsolved), or tag (unsolved) within the default or optionally specified group.
hubot zendesk <all|status|tag> tickets <group>(optional) - returns a list of tickets with the status (all=unsolved), or tag (unsolved) within the default or optionally specified group.

Group Commands:
hubot zendesk group alias <alias> <zendesk group_id> - creates an alias to easily assign tickets to a group.
hubot zendesk group load - Imports groups to robot.brain to reduce API calls and reports the names and group_id.
hubot zendesk group reset - Clears robot.brain and removes all stored groups and aliases.

Update Commands:
hubot zendesk update <ID> <status|priority|type> - Updates ticket with a private comment on who did it.
hubot zendesk update <ID> comment <text> - Will add a new private comment with the provided text.
hubot zendesk update <ID> group <Group Name or Alias> - assigns ticket to group.
hubot zendesk update <ID> tags <tag tag_1> - Replaces tags with the ones specified.
hubot zendesk update <IncidentID> link <ProblemNumber> - Links an incident to a problem.

hubot is also listening for #<ID> and will try to look it up.
```
