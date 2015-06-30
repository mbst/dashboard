require 'faraday'
require 'json'

url = $Credentials['sensu']['url']

class Event
  def initialize(jsonObject)
    @status = jsonObject['check']['status']
    @checkName = jsonObject['check']['name']
    @clientName = jsonObject['client']['name']
  end

  def isWarning
    @status == 1
  end

  def isCritical
    @status == 2
  end

  def isStage
    @clientName =~ /stage/ or @checkName =~ /stage/
  end

  def isProd
    @clientName =~ /prod/ or @checkName =~ /prod/
  end

  def isStashed(stashes)
    stashes.include? "silence/#{@clientName}" or stashes.include? "silence/#{@clientName}/#{@checkName}"
  end
end


SCHEDULER.every '20s' do
    conn = Faraday.new(:url => "#{url}") do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
      faraday.headers['Content-type'] = 'application/json'
    end

    begin
      stage_warn = []
      stage_crit = []
      prod_warn = []
      prod_crit = []

      stashes = JSON.parse(conn.get('/stashes').body).map {|o| o['path']}

      events = JSON.parse(conn.get('/events').body).map {|o| Event.new(o)}
      events.each do |e|
        next if e.isStashed(stashes)
        if e.isStage
          stage_warn << e if e.isWarning
          stage_crit << e if e.isCritical
        else
          prod_warn << e if e.isWarning
          prod_crit << e if e.isCritical
        end
      end

      send = {
        stage: {
          critical: stage_crit.size,
          warning: stage_warn.size
        },
        prod: {
          critical: prod_crit.size,
          warning: prod_warn.size
        }
      }
      send_event("sensu", send)

    rescue
      STDERR.puts "Couldn't fetch sensu things :(."
      STDERR.puts $!, *$@
    end
end
