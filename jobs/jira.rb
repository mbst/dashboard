require 'faraday'
require 'json'
require 'set'
require 'pp'

url = $Credentials['jira']['url']
username = $Credentials['jira']['username']
password = $Credentials['jira']['password']

Feature_id_field = 'customfield_10400'  # the field that has the id of a task's feature

def initials(name)
  name.split(' ').map {|w| w[0]}.join
end

def loadFeatureTitlesOfIssues(issues, conn)
  ids = Set.new
  issues.each { |i| ids << (i['fields'][Feature_id_field] || next) }
  mappings = ids.map do |id|
    begin
      response = conn.get("/rest/api/2/issue/#{id}")
      feature = JSON.parse(response.body)
      [id, feature['fields']['summary']]
    rescue
      [id, '???']
    end
  end
  Hash[mappings]
end

SCHEDULER.every '15s' do
    conn = Faraday.new(:url => url) do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
      faraday.headers['Content-type'] = 'application/json'
      faraday.basic_auth(username, password)
    end

    begin
      lastUpdatedResponse = conn.get('/rest/api/2/search', {
        maxResults: 10,
        jql: 'type = task and resolutiondate is not null ORDER BY resolutiondate DESC'
      })

      issues = JSON.parse(lastUpdatedResponse.body)['issues']
      featureTitles = loadFeatureTitlesOfIssues(issues, conn)

      lastUpdated = issues.map do |l|
        {
          assignee: initials(l['fields']['assignee']['displayName']),
          summary: l['fields']['summary'],
          feature: (featureTitles[l['fields'][Feature_id_field]] rescue nil),
          status: ((l['fields']['resolution']['name'] rescue nil) or l['fields']['status']['name']),
          updated: l['fields']['resolutiondate']
        }
      end

      output = lastUpdated.map do |l|
        time = DateTime.iso8601(l[:updated]).strftime('%a %k:%M')
        {
          label: "#{time} – " + (l[:feature] ? "#{l[:feature]}: " : '') + "#{l[:summary]}",
          value: "#{l[:status]} (#{l[:assignee]})"
        }
      end

      send_event("jira-last-updated", {items: output})
    rescue
      STDERR.puts "Couldn't fetch pagerduty last updated things :(."
      STDERR.puts $!, *$@
    end
end
