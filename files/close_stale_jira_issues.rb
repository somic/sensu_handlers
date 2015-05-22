#!/usr/bin/env ruby
#
#

require "#{File.dirname(__FILE__)}/sensu_jira_client"

def jira_server_options
end

def all_sensu_clients
end

def find_event_in_sensu(client_name, check_name)
end

def extract_info_from_labels(issue_hash)
end

jira = SensuJiraClient.new(jira_server_options)
jira.find_issues.each do |issue_hash|
  client_name, check_name = extract_info_from_labels(issue_hash)
  # we only close issues for those clients that are in clients list on *local*
  # sensu cluster because we need to get a confirmation that the event is no
  # longer happening before closing a jira issue
  if all_sensu_clients.include? client_name
    unless find_event_in_sensu(client_name, check_name)
      issue = jira.build_issue(client_name, check_name)
      issue.close_issue('This issue is stale, closing')
    end
  end
end
