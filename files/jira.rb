#!/usr/bin/env ruby

require "#{File.dirname(__FILE__)}/base"

class Jira < BaseHandler

  def build_labels
    user_labels = []
    user_labels += @event['check']['tags'] || []
    user_labels += team_data('tags') || []
    [
      "SENSU_#{@event['client']['name']}",
      "SENSU_#{@event['check']['name']}",
      "SENSU",
      *user_labels
    ].uniq.reject { |x| x.nil? }.map { |x|
      x.strip.gsub(/\s+/, '_')
    }
  end

  def create_issue(summary, description, project)
    if rate_limited? && issues_limit_per_minute_reached?
      puts 'Not opening a new jira issue - reached limit per minute'
      return handler_success
    end

    begin
      require 'jira'
      client = JIRA::Client.new(get_options)
      # In order to stop duplicates, we query JIRA for any open tickets
      # in the requested project that have the exact same client name and check name
      query_string = "labels='SENSU_#{@event['client']['name']}' AND labels='SENSU_#{@event['check']['name']}' AND resolution=Unresolved"
      existing_issues = client.Issue.jql(query_string)
      if existing_issues.length > 0
        # If there are tickets that match, we don't make a new one because it is already a known issue
        puts "Not creating a new issue, there are " + existing_issues.length.to_s + " issues already open for " + summary
      else
        puts "Creating a new jira ticket for: #{summary} on project #{project}"
        project_id = client.Project.find(project).id
        issue = client.Issue.build
        issue_json = {
          "fields"=>{
            "summary"=> summary,
            "description"=> description,
            "project"=> { "id"=>project_id },
            "issuetype"=> {"id"=>1},
            "labels" => build_labels
          }
        }
        issue.save(issue_json)
        url = get_options[:site] + '/browse/' + issue.key
        puts "Created issue #{issue.key} at #{url}"
      end
      incr_num_issues_per_minute if rate_limited?
      handler_success
    rescue Exception => e
      puts e.message
    end
  end

  def close_issue(output, project)
    begin
      require 'jira'
      client = JIRA::Client.new(get_options)
      query_string = "labels='SENSU_#{@event['client']['name']}' AND labels='SENSU_#{@event['check']['name']}' AND resolution=Unresolved"
      client.Issue.jql(query_string).each do | issue |
        url = get_options[:site] + '/browse/' + issue.key
        puts "Closing Issue: #{issue.key} (#{url})"

        occurrences = @event['occurrences'] rescue 'unknown'
        body = "This is fine:\n{code}#{uncolorize(output)}{code}"
        body += "\nOccurrences: #{occurrences}"

        # Let the world know why we are closing this issue.
        comment = issue.comments.build
        comment.save(:body => body)

        # Find the first transition to a closed state that we can perform.
        transitions_to_close = issue.transitions.all.select { |transition|
          # statusCategory key will only ever be 'new', 'indeterminate', or 'done'
          transition.attrs['to']['statusCategory']['key'] == 'done'
        }
        if transitions_to_close.empty?
          puts "Couldn't close #{issue.key} because no 'done' transitions found"
          return
        end

        # Perform a transition of the appropriate type.
        transition = issue.transitions.build()
        result = transition.save(:transition => { :id => transitions_to_close.first.id } )
        unless result
          puts "Couldn't close #{issue.key}: " + transition.attrs['errorMessages']
        end
      end
      handler_success
    rescue Exception => e
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
    summary = "#{@event['check']['name']} on #{client_display_name()} is #{status}"
    description = jira_description()
    output = @event['check']['output']
    begin
      timeout(10) do
        case @event['check']['status'].to_i
        when 0
          close_issue(output, project)
        else
          create_issue(summary, description, project)
        end
      end
    rescue Timeout::Error
      puts 'Timed out while attempting contact JIRA for ' + @event['action'] + summary
    end
  end

  def get_options
    options = {
      :username         => handler_settings['username'],
      :password         => handler_settings['password'],
      :site             => handler_settings['site'],
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

  def issues_limit_per_minute_reached?
   curr_value = redis.get(rate_limit_redis_key).to_i
   limit = @event['check']['max_issues_per_minute'].to_i
   limit = 3 if limit < 3 # safeguard against unexpected, might remove in future
   curr_value >= limit
  end

  def rate_limited?
    @event['check'].has_key? 'max_issues_per_minute'
  end

  # a key per event per minute, each key expires in redis automatically
  def rate_limit_redis_key
    return @rate_limit_redis_key if @rate_limit_redis_key

    timestamp = Time.now
    timestamp = timestamp.to_i - timestamp.sec
    @rate_limit_redis_key =
      "jira_handler_rate_limit::#{@event['check']['name']}::#{timestamp}"
  end

  def incr_num_issues_per_minute
    redis.incr(rate_limit_redis_key)
    redis.expire(rate_limit_redis_key, 120) # 2 minutes
  end

end
