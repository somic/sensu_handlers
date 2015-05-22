#!/usr/bin/env ruby

require 'rubygems'
require 'jira'

class SensuJiraClient

  attr_reader :jira_server_options

  def initialize(jira_server_options)
    @jira_server_options = jira_server_options
    @labels = [ "labels='SENSU'" ]
  end

  def client
    @client ||= JIRA::Client.new(jira_server_options)
  end

  def find_issues(resolution='Unresolved')
    query_string = (labels + [ "resolution=#{resolution}" ]).join(' AND ')
    client.Issue.jql(query_string)
  end

  def build_issue(client_name, check_name)
    SensuJiraIssue.new(
      jira_server_options=jira_server_options,
      sensu_client_name=client_name,
      sensu_check_name=check_name
    )
  end

end

class SensuJiraIssue < SensuJiraClient

  attr_reader :sensu_client_name, :sensu_check_name

  def initialize(jira_server_options, sensu_client_name, sensu_check_name)
    @sensu_client_name = sensu_client_name
    @sensu_check_name = sensu_check_name
    @jira_server_options = jira_server_options

    @labels = [
      "labels='SENSU'",
      "labels='SENSU_#{sensu_check_name}'",
      "labels='SENSU_#{sensu_client_name}'"
    ]
  end

  def issue_already_exists?
    find_issues.any?
  end

  def close_issue(output)
    find_issues.each do |issue|
      url = jira_server_options[:site] + '/browse/' + issue.key
      puts "Closing Issue: #{issue.key} (#{url})"

      # Let the world know why we are closing this issue.
      comment = issue.comments.build
      comment.save(:body => "This is fine:\n#{output}")

      # Find the first transition to a closed state that we can perform.
      transitions_to_close = issue.transitions.all.select { |transition|
        # statusCategory key will only ever be 'new', 'indeterminate', or 'done'
        transition.attrs['to']['statusCategory']['key'] == 'done'
      }
      if transitions_to_close.empty?
        puts "Couldn't close #{issue.key} because no 'done' transitions found"
        next
      end

      transition = issue.transitions.build()
      result = transition.save(:transition => { :id => transitions_to_close.first.id } )
      unless result
        puts "Couldn't close #{issue.key}: " + transition.attrs['errorMessages']
        next
      end
    end
  end

  def create_issue(summary, full_description, project)
    if issue_already_exists?
      puts "Not creating a new issue for" + summary
      return
    end

    puts "Creating a new jira ticket for: #{summary} on project #{project}"
    project_id = client.Project.find(project).id
    issue = client.Issue.build
    issue_json = {
      "fields"=>{
        "summary"=> summary,
        "description"=> full_description,
        "project"=> { "id"=>project_id },
        "issuetype"=> {"id"=>1},
        "labels" => labels,
      }
    }
    issue.save(issue_json)
    url = jira_server_options[:site] + '/browse/' + issue.key
    puts "Created issue #{issue.key} at #{url}"
  end
end
