#!/usr/bin/env ruby

require "#{File.dirname(__FILE__)}/base"
require "#{File.dirname(__FILE__)}/sensu_jira_client"

class JiraHandler < BaseHandler

  def jira_client
    @jira_client ||= SensuJiraIssue.new(
      sensu_client_name=@event['client']['name'],
      sensu_check_name=@event['check']['name'],
      jira_server_options=get_options)
  end

  def create_issue(summary, full_description, project)
    begin
      jira_client.create_issue(summary, full_description, project)
      handler_success
    rescue Exception => e
      handler_failure
      puts e.message
    end
  end

  def close_issue(output)
    begin
      jira_client.close_issue(output)
      handler_success
    rescue Exception => e
      handler_failure
      puts e.message
    end
  end

  def should_ticket?
    @event['check']['ticket'] || false
  end

  def project
    @event['check']['project'] || team_data('project')
  end

  def handle
    return false if !should_ticket?
    return false if !project
    status = human_check_status()
    summary = @event['check']['name'] + " on " + @event['client']['name'] + " is " + status
    full_description = full_description()
    output = @event['check']['output']
    begin
      timeout(10) do
        case @event['check']['status'].to_i
        when 0
          close_issue(output)
        else
          create_issue(summary, full_description, project)
        end
      end
    rescue Timeout::Error
      puts 'Timed out while attempting contact JIRA for ' + @event['action'] + summary
    end
  end

  def get_options
    options = {
      :username         => settings['jira']['username'],
      :password         => settings['jira']['password'],
      :site             => settings['jira']['site'],
      :context_path     => '',
      :auth_type        => :basic,
      :use_ssl          => true,
      :ssl_verify_mode  => OpenSSL::SSL::VERIFY_NONE
    }
    return options
  end

  def handler_failure(exception_text)
    #File.open('/var/log/sensu/jira_handler_failure.log', 'w') { |file| file.write("Jira handler failed with: #{exception_text}") }
  end

  def handler_success
    #File.delete('/var/log/sensu/jira_handler_failure.log')
  end

end
