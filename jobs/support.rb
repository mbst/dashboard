require 'faraday'
require 'json'
require 'set'
require 'holidays'
require 'active_support'
require 'pp'

url = $Credentials['jira']['url']
username = $Credentials['jira']['username']
password = $Credentials['jira']['password']

Support_class_field = 'customfield_10900'  # the field that holds a support ticket's classification

SupportDeadlines = {
  'Glitch' => {
    response: '1/24'.to_r,
    warning: 4,
    resolution: 5,
    working_hours: true  # i.e. only include working days/hours in elapsed time
  },
  'Degradation' => {
    response: '1/24'.to_r,
    warning: '21/24'.to_r,
    resolution: 1,
    working_hours: true  # i.e. only include working days/hours in elapsed time
  },
  'Failure' => {
    response: '1/24'.to_r,
    warning: '3/24'.to_r,
    resolution: '4/24'.to_r
  }
}

# Adds on extra time to allow for out of hours, weekends and bank holidays
def adjustDeadline(deadline, created)
  # Adjust for working hours
  #
  sixOClock = DateTime.new(deadline.year, deadline.month, deadline.day, 18, 0, deadline.offset)
  if sixOClock.to_time.dst? then
    sixOClock += '1/24'.to_r
  end
  #
  if (deadline - sixOClock) > 0 then
    deadline += '16/24'.to_r  # 6pm -> 10am
  end

  # Adjust for weekends
  #
  day = created.to_date
  while day <= deadline.to_date
    if day.wday == 0 or day.wday == 6  # sun or sat
      deadline += 1
    end
    unless Holidays.on(day, :gb_eng, :observed).empty?
      deadline += 1
    end
    day += 1
  end

  deadline
end

def fixUrgency(classification, created, now)
  begin
    timeToWarn = created + SupportDeadlines[classification][:warning]
    timeToFix = created + SupportDeadlines[classification][:resolution]
    if SupportDeadlines[classification][:working_hours]
      timeToWarn = adjustDeadline(timeToWarn, created)
      timeToFix = adjustDeadline(timeToFix, created)
    end
  rescue
    return nil
  end

  urgency = case
    when now > timeToFix
      :late
    when now > timeToWarn
      :warning
    else
      nil
  end

  {deadline: timeToFix, urgency: urgency}
end

SCHEDULER.every '20s' do
    conn = Faraday.new(:url => url) do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
      faraday.headers['Content-type'] = 'application/json'
      faraday.basic_auth(username, password)
    end

    begin
      lastUpdatedResponse = conn.get('/rest/api/2/search', {
        maxResults: 200,
        jql: 'project = SUPPORT and resolution is null'
      })

      now = DateTime.now

      issues = JSON.parse(lastUpdatedResponse.body)['issues'].map do |i|
        classification = i['fields'][Support_class_field]['value'] rescue nil
        created = DateTime.parse(i['fields']['created'])
        summary = i['fields']['summary'].gsub /^((Re|Fwd?):?\s*)*/i, ''
        urgency = fixUrgency(classification, created, now)

        {
          classification: classification,
          created: created,
          summary: summary,
          fixUrgency: (urgency[:urgency] rescue nil),
          deadline: (urgency[:deadline] rescue nil)
          # TODO: separately report failure to respond
        }
      end
      send_event("jira-support-issues", {issues: issues.sort_by{|i| i[:deadline] or (i[:classification].nil? ? now : DateTime.new(3000))}})
    rescue
      STDERR.puts "Couldn't fetch pagerduty support things :(."
      STDERR.puts $!, *$@
    end
end
