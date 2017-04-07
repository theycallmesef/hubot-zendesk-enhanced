# hubot-zendesk

Queries Zendesk for information about support tickets

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
HUBOT_ZENDESK_GROUP - (optional) Limits default searches to a group (name or ID #) or groups (comma sperated group ID #). 
```

# Commands:
```
hubot zendesk <all|status|tag> tickets - returns a count of tickets with the status (all=unsolved), or tag (unsolved).
hubot zendesk <all|status|tag> tickets <group> - returns a count of tickets assigned to provided group. 
hubot zendesk list <all|status|tag> tickets - returns a list of all unsolved tickets, or with the provided status.
hubot zendesk list <all|status|tag> tickets <group> - returns list of tickets assigned to provided group.
hubot zendesk ticket <ID> - returns information about the specified ticket
