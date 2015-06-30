require 'faraday'
require 'json'

url = $Credentials['pagerduty']['url']
api_key = $Credentials['pagerduty']['api_key']

triggered = 0
acknowledged = 0

SCHEDULER.every '5s' do
    conn = Faraday.new(:url => "#{url}") do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
      faraday.headers['Content-type'] = 'application/json'
      faraday.headers['Authorization'] = "Token token=#{api_key}"
    end

    begin
      triggered = JSON.parse(conn.get('/api/v1/incidents/count', status: 'triggered').body)['total']
      acked = JSON.parse(conn.get('/api/v1/incidents/count', status: 'acknowledged').body)['total']

      send_event("pagerduty", {
        acked: (acked || 0),
        triggered: (triggered || 0),
        open: (triggered+acked)
      })
    rescue
      STDERR.puts "Couldn't fetch pagerduty things :(."
      STDERR.puts $!, *$@
    end
end
