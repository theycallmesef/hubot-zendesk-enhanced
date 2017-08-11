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
#   vs. 'Group Name')
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
#   hubot zendesk <all|status|tag> tickets - returns a count of tickets with the status (all=unsolved), or tag (unsolved).
#   hubot zendesk <all|status|tag> tickets <group> - returns a count of tickets assigned to provided group.
#   hubot zendesk list <all|status|tag> tickets - returns a list of tickets with the status (all=unsolved), or tag (unsolved).
#   hubot zendesk list <all|status|tag> tickets <group> - returns list of tickets assigned to provided group.
#   hubot zendesk ticket <ID> - returns information about the specified ticket
#   hubot zendesk ticket <ID> comment <text> - Posts a private comment to specified ticket. 

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

  robot.respond /(?:zendesk|zd) ticket ([\d]+) comment (.*)$/i, (msg) ->
    if process.env.HUBOT_ZENDESK_DISABLE_UPDATE
      msg.send "Sorry #{msg.message.user.name}, but your administrator disabled comments through me."
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
