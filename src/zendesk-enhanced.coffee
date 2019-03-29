# Description:
#   Allows hubot to query and update Zendesk support tickets.
#
# Notes:
#   This script interacts with the Zendesk REST API, which
#   can be found here: https://developer.zendesk.com/rest_api
#   You should note that if you're going to be using an API
#   token set up through zendesk, you'll still need to provide
#   a username. Usually it's \token appeneded to the email
#   address of the user that set up the token. That user
#   will be reported as the author of any changes made to
#   tickets. Also per the Zendesk API group names that contain
#   spaces must be encapsulated with single quotes. (ex. Group
#   vs. 'Group Name') You should note that updates made to
#   tickets use whatever user you authenticate with, so it's
#   recommended to use a meta account to do this.
#
# Configuration:
#   HUBOT_ZENDESK_USER - (required)
#   HUBOT_ZENDESK_PASSWORD - (required)
#   HUBOT_ZENDESK_SUBDOMAIN - (required) subdomain for your Zendesk group. (http://<subdomain>.zendesk.com/)
#   HUBOT_ZENDESK_HEAR - (optional) If present, activates responses without being address directly.
#   HUBOT_ZENDESK_EMOJI - (optional) Appends text for emoji icon to responses. (ex: :zendesk:)
#   HUBOT_ZENDESK_GROUP - (optional) Limits default searches to a group (name or ID #) or groups (comma separated).
#   HUBOT_ZENDESK_ADAPTER - (optional) Appends provided adapter name to comments. Defaults to 'Hubot'.
#   HUBOT_ZENDESK_DISABLE_UPDATE - (optional) If present, disables hubot's ability to update tickets.
#
# Commands:
#   hubot zendesk help - returns all commands for "zendesk" command.
#   hubot zendesk group help - returns all commands for "zendesk group" command.
#   hubot zendesk update help - returns all commands for "zendesk update" command.
#   hubot zendesk ticket <ID> - Returns information about the specified ticket.
#   hubot zendesk list <all|status|tag> tickets <group>(optional)- returns a list of tickets with the status (all=unsolved), or tag (unsolved). Group is optional.
#   hubot zendesk <all|status|tag> tickets <group>(optional) - returns a count of tickets with the status (all=unsolved), or tag (unsolved). Group is optional.
#   hubot zendesk group alias <alias> <zendesk group_id> - creates an alias to easily assign tickets to a group.
#   hubot zendesk update <ID> <status|priority|type> - Updates ticket with a private comment on who did it.
#   hubot zendesk update <ID> comment <text> - Posts a private comment to specified ticket.
#   hubot zendesk update <ID> group <Full Group Name or Alias> - assigns ticket to group.
#   hubot zendesk update <ID> tags <tag tag_1> - Replaces tags with the ones specified.
#   hubot zendesk update <IncidentID> link <ProblemID> - Links an incident to a problem.

auth = new Buffer("#{process.env.HUBOT_ZENDESK_USER}:#{process.env.HUBOT_ZENDESK_PASSWORD}").toString('base64')
side_load = "?include=users,groups"
tickets_url = "https://#{process.env.HUBOT_ZENDESK_SUBDOMAIN}.zendesk.com/tickets"
unsolved_query = "search.json?query=status<solved+type:ticket"
zdicon = process.env.HUBOT_ZENDESK_EMOJI or ''
zendesk_password = process.env.HUBOT_ZENDESK_PASSWORD
zendesk_url = "https://#{process.env.HUBOT_ZENDESK_SUBDOMAIN}.zendesk.com/api/v2"
zendesk_user = process.env.HUBOT_ZENDESK_USER
adapter = process.env.HUBOT_ZENDESK_ADAPTER or 'Hubot'
try
  default_group = "+group:#{process.env.HUBOT_ZENDESK_GROUP.replace /,/g, '+group:'}"
catch error
  default_group = ''

zdgroupdefault =
  Example_Name_or_Alias:
    name: 'This is an example long name in Zendesk'
    id: '12345'

zendesk_request = (msg, url, handler) ->
  msg.http("#{zendesk_url}/#{url}")
    .headers(Authorization: "Basic #{auth}", Accept: "application/json")
      .get() (err, res, body) ->
        if err
          msg.send "Zendesk error: #{err}"
          return

        content = JSON.parse(body)

        if content.error?
          if content.error?.title
            msg.send "Zendesk error: #{content.error.title}"
          else
            msg.send "Zendesk error: #{content.error}"
          return

        handler content

zendesk_update = (msg, ticket_id, request_body, handler) ->
  msg.http("#{zendesk_url}/tickets/#{ticket_id}.json")
    .headers('Authorization': "Basic #{auth}", 'Content-Type': "application/json", 'Accept': "application/json")
      .put(request_body) (err, res, body) ->
        if err
          msg.send "Zendesk error: #{err}"
          return

        content = JSON.parse(body)

        if content.error?
          if content.error?.title
            msg.send "Zendesk error: #{content.error.title}"
          else
            msg.send "Zendesk error: #{content.error}"
          return

        handler content

module.exports = (robot) ->

  # store groups in hubot brain
  zd_group_store = (msg, key, group_name, group_id) ->
    zdgroups = robot.brain.get('zdgroups')
    if zdgroups is null
      zdgroups = zdgroupdefault
    zdgroups[ key ] =
      name: group_name
      id: group_id
    robot.brain.set('zdgroups', zdgroups)
    zdgroups

  # Assign a ticket to group
  robot.respond /(?:zendesk|zd) update ([\d]+) group (.*)$/i, (msg) ->
    if process.env.HUBOT_ZENDESK_DISABLE_UPDATE
      msg.send "Sorry #{msg.message.user.name}, but your administrator disabled updates through me."
      return
    ticket_id = msg.match[1]
    ticket_commentor = "#{msg.message.user.real_name} <@#{msg.message.user.name}> (#{msg.message.user.id})"
    ticket_comment = "Reassigned by #{ticket_commentor} via #{adapter}"
    group_query = msg.match[2]
    braingroup = robot.brain.get('zdgroups')
    if braingroup[ group_query ]
      json_body =
        ticket:
          group_id: braingroup[ group_query ].id
          comment:
            body: ticket_comment
            public: "no"
      request_body =JSON.stringify(json_body)
      zendesk_update msg, ticket_id, request_body, (result) ->
        msg.send "#{zdicon}Ticket #{ticket_id} was assigned to #{braingroup[ group_query].name} (#{braingroup[ group_query].id})."
    else
      zendesk_request msg, "search.json?query=type:group '#{group_query}'", (results) ->
        if results.count is 0
          msg.send "Sorry, I couldn't find a group called #{group_query}, check your spelling or add an alias."
        else
          json_body =
            ticket:
              group_id: results.results[0].id
              comment:
                body: ticket_comment
                public: "no"
          request_body =JSON.stringify(json_body)
          zendesk_update msg, ticket_id, request_body, (result) ->
            msg.send "Ticket #{result.ticket.id} was assigned to #{group_query} (#{result.ticket.group_id})."
          zd_group_store msg, results.results[0].name, results.results[0].name, results.results[0].id, (zdgroups) ->

  # Add an alias for a group to hubot brain
  robot.respond /(?:zendesk|zd) group alias (.*) ([\d]+)$/i, (msg) ->
    if process.env.HUBOT_ZENDESK_DISABLE_UPDATE
      msg.send "Sorry #{msg.message.user.name}, but your administrator disabled updates through me."
      return
    alias_name = msg.match[1]
    group_id = msg.match[2]
    zendesk_request msg, "groups/#{group_id}.json", (result) ->
      msg.send "Added #{alias_name} alias for #{result.group.name}."
      zd_group_store msg, alias_name, result.group.name, result.group.id, (zdgroups) ->

  # Reset added groups to default
  robot.respond /(?:zendesk|zd) group reset$/i, (msg) ->
    if process.env.HUBOT_ZENDESK_DISABLE_UPDATE
      msg.send "Sorry #{msg.message.user.name}, but your administrator disabled updates through me."
      return
    robot.brain.set('zdgroups', zdgroupdefault)
    msg.send "Cached groups and aliases cleared."

  # Pull groups from zendesk and add them to hubot brain
  robot.respond /(?:zendesk|zd) group load$/i, (msg) ->
    if process.env.HUBOT_ZENDESK_DISABLE_UPDATE
      msg.send "Sorry #{msg.message.user.name}, but your administrator disabled updates through me."
      return
    zendesk_request msg, "search.json?query=type:group", (results) ->
      for group in results.results
        msg.send "Added: #{group.name} (#{group.id})"
        zd_group_store msg, group.name, group.name, group.id, (zdgroups) ->

  # Update a ticket with a private comment
  robot.respond /(?:zendesk|zd) update ([\d]+) comment (.*)$/i, (msg) ->
    if process.env.HUBOT_ZENDESK_DISABLE_UPDATE
      msg.send "Sorry #{msg.message.user.name}, but your administrator disabled updates through me."
      return
    ticket_commentor = "#{msg.message.user.real_name} <@#{msg.message.user.name}> (#{msg.message.user.id})"
    ticket_id = msg.match[1]
    ticket_comment = msg.match[2]
    ticket_comment += "\n\nSubmitted by #{ticket_commentor} via #{adapter}"
    json_body =
      ticket:
        comment:
          body: ticket_comment
          public: "no"
    request_body =JSON.stringify(json_body)
    zendesk_update msg, ticket_id, request_body, (result) ->
      msg.send "#{zdicon}Private comment was added to #{result.ticket.id}:\n#{result.audit.events[0].body}"

  # Update ticket priority
  robot.respond /(?:zendesk|zd) update ([\d]+) (low|normal|high|urgent)$/i, (msg) ->
    if process.env.HUBOT_ZENDESK_DISABLE_UPDATE
      msg.send "Sorry #{msg.message.user.name}, but your administrator disabled updates through me."
      return
    ticket_commentor = "#{msg.message.user.real_name} <@#{msg.message.user.name}> (#{msg.message.user.id})"
    ticket_id = msg.match[1]
    ticket_priority = msg.match[2].toLowerCase()
    ticket_comment = "Priority updated by #{ticket_commentor} via #{adapter}"
    json_body =
      ticket:
        priority: ticket_priority
        comment:
          body: ticket_comment
          public: "no"
    request_body =JSON.stringify(json_body)
    zendesk_update msg, ticket_id, request_body, (result) ->
      msg.send "#{zdicon}Priority was updated on ticket #{result.ticket.id}"

  # Update Ticket status
  robot.respond /(?:zendesk|zd) update ([\d]+) (open|pending|solved)$/i, (msg) ->
    if process.env.HUBOT_ZENDESK_DISABLE_UPDATE
      msg.send "Sorry #{msg.message.user.name}, but your administrator disabled updates through me."
      return
    ticket_commentor = "#{msg.message.user.real_name} <@#{msg.message.user.name}> (#{msg.message.user.id})"
    ticket_id = msg.match[1]
    ticket_status = msg.match[2].toLowerCase()
    ticket_comment = "Status updated by #{ticket_commentor} via #{adapter}"
    json_body =
      ticket:
        status: ticket_status
        comment:
          body: ticket_comment
          public: "no"
    request_body =JSON.stringify(json_body)
    zendesk_update msg, ticket_id, request_body, (result) ->
      msg.send "#{zdicon}Status was updated on ticket #{result.ticket.id}"

  # Update Ticket type
  robot.respond /(?:zendesk|zd) update ([\d]+) (problem|incident|question|task)$/i, (msg) ->
    if process.env.HUBOT_ZENDESK_DISABLE_UPDATE
      msg.send "Sorry #{msg.message.user.name}, but your administrator disabled updates through me."
      return
    ticket_commentor = "#{msg.message.user.real_name} <@#{msg.message.user.name}> (#{msg.message.user.id})"
    ticket_id = msg.match[1]
    ticket_type = msg.match[2].toLowerCase()
    ticket_comment = "Type updated by #{ticket_commentor} via #{adapter}"
    json_body =
      ticket:
        type: ticket_type
        comment:
          body: ticket_comment
          public: "no"
    request_body =JSON.stringify(json_body)
    zendesk_update msg, ticket_id, request_body, (result) ->
      msg.send "#{zdicon}Ticket type was updated on ticket #{result.ticket.id}"

  # Update Ticket tags
  robot.respond /(?:zendesk|zd) update ([\d]+) tags (.*)$/i, (msg) ->
    if process.env.HUBOT_ZENDESK_DISABLE_UPDATE
      msg.send "Sorry #{msg.message.user.name}, but your administrator disabled updates through me."
      return
    ticket_commentor = "#{msg.message.user.real_name} <@#{msg.message.user.name}> (#{msg.message.user.id})"
    ticket_id = msg.match[1]
    ticket_tags = msg.match[2].toLowerCase()
    ticket_comment = "Tags updated by #{ticket_commentor} via #{adapter}"
    json_body =
      ticket:
        tags: ticket_tags
        comment:
          body: ticket_comment
          public: "no"
    request_body =JSON.stringify(json_body)
    zendesk_update msg, ticket_id, request_body, (result) ->
      msg.send "#{zdicon}Ticket tags were set for ticket #{result.ticket.id}"

  # Link a ticket to a problem
  robot.respond /(?:zendesk|zd) update ([\d]+) link ([\d]+)$/i, (msg) ->
    if process.env.HUBOT_ZENDESK_DISABLE_UPDATE
      msg.send "Sorry #{msg.message.user.name}, but your administrator disabled updates through me."
      return
    ticket_commentor = "#{msg.message.user.real_name} <@#{msg.message.user.name}> (#{msg.message.user.id})"
    ticket_id = msg.match[1]
    problem_id_lnk = msg.match[2]
    zendesk_request msg, "tickets/show_many.json?ids=#{ticket_id},#{problem_id_lnk}", (result) ->
      id_0 = "#{result.tickets[0].id}"
      id_1 = "#{result.tickets[1].id}"
      type_0 = "#{result.tickets[0].type}"
      type_1 = "#{result.tickets[1].type}"
      if id_0 is ticket_id and /incident/i.test(type_0) is false or id_1 is ticket_id and /incident/i.test(type_1) is false
        msg.send "Sorry, ticket #{ticket_id} isn't an incident."
      else if id_0 is problem_id_lnk and /problem/i.test(type_0) is false or id_1 is problem_id_lnk and /problem/i.test(type_1) is false
        msg.send "Sorry, ticket #{problem_id_lnk} isn't a problem."
      else
        ticket_comment = "Ticket linked by #{ticket_commentor} via #{adapter}"
        json_body =
          ticket:
            problem_id: problem_id_lnk
            comment:
              body: ticket_comment
              public: "no"
        request_body =JSON.stringify(json_body)
        zendesk_update msg, ticket_id, request_body, (result) ->
          msg.send "#{zdicon}Incident #{result.ticket.id} was linked to problem #{problem_id_lnk}"

  # return ticket count of query in default group
  robot.respond /(?:zendesk|zd) (\w+) tickets$/i, (msg) ->
    query = msg.match[1].toLowerCase()
    if /new|open|pending|solved/i.test(query) is true
      zendesk_request msg, "search.json?query=status:#{query}+type:ticket#{default_group}", (results) ->
        msg.send "#{zdicon}There are currently #{results.count} #{query} tickets."
    else if /all/i.test(query) is true
      zendesk_request msg, unsolved_query + default_group, (results) ->
        msg.send "#{zdicon}There are currently #{results.count} unsolved tickets."
    else
      zendesk_request msg, unsolved_query + "+tags:#{query}" + default_group, (results) ->
        msg.send "#{zdicon}There are currently #{results.count} unsolved tickets tagged with #{query}."

  # Return ticket count of query in a group
  robot.respond /(?:zendesk|zd) (\w+) tickets (.*)$/i, (msg) ->
    query = msg.match[1].toLowerCase()
    group = msg.match[2]
    if /new|open|pending|solved/i.test(query) is true
      zendesk_request msg, "search.json?query=status:#{query}+type:ticket+group:#{group}", (results) ->
        msg.send "#{zdicon}There are currently #{results.count} #{query} tickets under #{group}."
    else if /all/i.test(query) is true
      zendesk_request msg, unsolved_query + "+group:#{group}", (results) ->
        msg.send "#{zdicon}There are currently #{results.count} unsolved tickets in #{group}."
    else
      zendesk_request msg, unsolved_query + "+tags:#{query}" + "+group:#{group}", (results) ->
        msg.send "#{zdicon}#{results.count} tickets tagged with #{query} in #{group}."

  # List tickets of query in default group
  robot.respond /(?:zendesk|zd) list (\w+) tickets$/i, (msg) ->
    query = msg.match[1].toLowerCase()
    if /new|open|pending|solved/i.test(query) is true
      zendesk_request msg, "search.json?query=status:#{query}+type:ticket#{default_group}", (results) ->
        message = "#{zdicon}There are currently #{results.count} #{query} tickets:"
        for result in results.results
          message += "\n#{zdicon}Ticket #{result.id} #{result.subject} (#{result.status.toUpperCase()})[#{result.priority}]: #{tickets_url}/#{result.id}"
        msg.send message
    else if /all/i.test(query) is true
      zendesk_request msg, unsolved_query + default_group, (results) ->
        message = "#{zdicon}There are currently #{results.count} unsolved tickets:"
        for result in results.results
          message += "\n#{zdicon}Ticket #{result.id} #{result.subject} (#{result.status.toUpperCase()})[#{result.priority}]: #{tickets_url}/#{result.id}"
        msg.send message
    else
      zendesk_request msg, unsolved_query + "+tags:#{query}" + default_group, (results) ->
        message = "#{zdicon}There are currently #{results.count} unsolved #{query} tagged tickets:"
        for result in results.results
          message += "\n#{zdicon}Ticket #{result.id} #{result.subject} (#{result.status.toUpperCase()})[#{result.priority}]: #{tickets_url}/#{result.id}"
        msg.send message

  # List tickets of query in a group
  robot.respond /(?:zendesk|zd) list (\w+) tickets (.*)$/i, (msg) ->
    query = msg.match[1].toLowerCase()
    group = msg.match[2]
    if /new|open|pending|solved/i.test(query) is true
      zendesk_request msg, "search.json?query=status:#{query}+type:ticket+group:#{group}", (results) ->
        message = "#{zdicon}There are currently #{results.count} #{query} tickets in #{group}:"
        for result in results.results
          message += "\n#{zdicon}Ticket #{result.id} #{result.subject} (#{result.status.toUpperCase()})[#{result.priority}]: #{tickets_url}/#{result.id}"
        msg.send message
    else if /all/i.test(query) is true
      zendesk_request msg, unsolved_query + "+group:#{group}", (results) ->
        message = "#{zdicon}There are currently #{results.count} unsolved tickets in #{group}:"
        for result in results.results
          message += "\n#{zdicon}Ticket #{result.id} #{result.subject} (#{result.status.toUpperCase()})[#{result.priority}]: #{tickets_url}/#{result.id}"
        msg.send message
    else
      zendesk_request msg, unsolved_query + "+tags:#{query}" + "+group:#{group}", (results) ->
        message = "#{zdicon}There are currently #{results.count} unsolved #{query} tagged tickets in #{group}:"
        for result in results.results
          message += "\n#{zdicon}Ticket #{result.id} #{result.subject} (#{result.status.toUpperCase()})[#{result.priority}]: #{tickets_url}/#{result.id}"
        msg.send message

  # Print info of a ticket
  robot.respond /(?:zendesk|zd) ticket ([\d]+)$/i, (msg) ->
    ticket_id = msg.match[1]
    zendesk_request msg, "tickets/#{ticket_id}.json", (result) ->
      if result.error
        msg.send result.description
        return
      message = "#{zdicon}#{tickets_url}/#{result.ticket.id}"
      message += "\n>##{result.ticket.id} #{result.ticket.subject} (#{result.ticket.status.toUpperCase()})"
      message += "\n>Priority: #{result.ticket.priority}"
      message += "\n>Type: #{result.ticket.type}"
      message += "\n>Updated: #{result.ticket.updated_at}"
      message += "\n>Added: #{result.ticket.created_at}"
      message += "\n>Description:"
      message += "\n>-------"
      message += "\n>#{result.ticket.description.replace /\n/g, "\n>"}"
      msg.send message

  # Help - General (count, query, info)
  robot.respond /(?:zendesk|zd) help$/i, (msg) ->
    message = "Here's some additional information about zendesk Commands\nYou can substitute zd for zendesk with any command."
    message += "\n>zendesk group help"
    message += "\nList help for group command"
    message += "\n>zendesk update help"
    message += "\nList help for update command"
    message += "\n>zendesk ticket <TicketNumber>"
    message += "\nWill list the details of a ticket"
    message += "\n>zendesk list <query> tickets"
    message += "\nWill list the the tickets of a query."
    message += "\nValid options for <query> are: NEW OPEN PENDING SOLVED ALL <TAG>"
    message += "\n>zendesk list <query> tickets <group>"
    message += "\nWill list the the tickets of a query within a group."
    message += "\nValid options for <query> are: NEW OPEN PENDING SOLVED ALL <TAG>"
    message += "\n>zendesk <query> tickets"
    message += "\nWill return a count of a query."
    message += "\nValid options for <query> are: NEW OPEN PENDING SOLVED ALL <TAG>"
    message += "\n>zendesk <query> tickets <group>"
    message += "\nWill return a count of a query in a group."
    message += "\nValid options for <query> are: NEW OPEN PENDING SOLVED ALL <TAG>"
    message += "\nI'm also listening for #<TicketNumber> and will try to look it up"
    msg.send message

  # Help - Group (alias, reset, load)
  robot.respond /(?:zendesk|zd) group help$/i, (msg) ->
    message = "Here's some additional information about zendesk group Commands\nYou can substitute zd for zendesk with any command."
    message += "\n>zendesk group alias <Alias> <Group>"
    message += "\nWill set a local alias for an existing group"
    message += "\n>zendesk group reset"
    message += "\nWill reset added groups to default"
    message += "\n>zendesk group load"
    message += "\nWill Pull groups from zendesk and add them to the known list"
    msg.send message

  # Help - Update
  robot.respond /(?:zendesk|zd) update help$/i, (msg) ->
    message = "Here's some additional information about updating tickets\nYou can substitute zd for zendesk with any command."
    message += "\n>zendesk update <TicketNumber> <Status>"
    message += "\nWill change the status of the ticket. Valid statuses are: OPEN PENDING and SOLVED"
    message += "\n>zendesk update <TicketNumber> <Priority>"
    message += "\nWill change the priority of the ticket. Valid priorites are: LOW NORMAL HIGH and URGENT"
    message += "\n>zendesk update <TicketNumber> <Type>"
    message += "\nWill change the type of ticket. Valid types are: TASK INCIDENT QUESTION and PROBLEM"
    message += "\n>zendesk update <TicketNumber> <Tags>"
    message += "\nWill overwrite the tags for the ticket with only the ones you supply. New tags are separated with space. For multi-word tags, use a _ instead of a space."
    message += "\n>zendesk update <TicketNumber> group <Group Name or Alias>"
    message += "\nWill assign the ticket to a group, using the full name or an alias. (You can set up an alias with zd group alias <AliasName> <group_id>) Hubot stores valid names in robot.brain so it doesn't have to make two API calls in the future. If you've entered a bad alias, or the group names in zendesk have changed you can reset the known names and aliases (zd group reset)."
    message += "\n>zendesk update <IncidentNumber> link <ProblemNumber>"
    message += "\nWill link an Incident to a Problem and also check to make sure the ticket types are right before trying to link them."
    message += "\n>zendesk update <TicketNumber> comment <More text>"
    message += "\nWill add a new private comment with the provided text."
    msg.send message

  # Listen for a number and do a Zendesk lookup
  robot.hear /#([\d]+)/gi, (msg) ->
    if process.env.HUBOT_ZENDESK_HEAR
      msg.send "It sounds like you're referencing a Zendesk ticket, let me look that up for you..."
      for ticket_id in msg.match
        zendesk_request msg, "tickets/#{ticket_id.replace /#/, ""}.json", (result) ->
          if result.error
            msg.send "Zendesk error: #{result.error}"
            return
          message = "\n#{zdicon}Ticket #{result.ticket.id} #{result.ticket.subject} (#{result.ticket.status.toUpperCase()})[#{result.ticket.priority}]"
          message += "\n>#{tickets_url}/#{result.ticket.id}"
          msg.send message
