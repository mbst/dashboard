require 'net/http'
require 'json'

minsToAverage = 5  # how many minutes (before now) should be included in the displayed mean
minsToGraph = 20  # how many minutes (before now) should be included in the graph output

stats = [
  {
    name: 'atlas-content-single',
    graphiteId: 'api.atlas.atlas_single_content_single_id.mean'
  },
  # {
  #   name: 'atlas-content-multi',
  #   graphiteId: 'api.atlas.atlas_single_content_multi_id.mean'
  # },
  {
    name: 'atlas-schedule',
    graphiteId: 'api.atlas.atlas_schedule.mean'
  },
  {
    name: 'voila-content-single',
    graphiteId: 'api.voila.voila_single_content_single_id.mean'
  },
  # {
  #   name: 'voila-content-multi',
  #   graphiteId: 'api.voila.voila_single_content_multi_id.mean'
  # },
  {
    name: 'voila-schedule',
    graphiteId: 'api.voila.voila_schedule.mean'
  },
]

SCHEDULER.every '20s' do
  now = DateTime.now()

  stats.each do |s|
    uri = URI("http://graphite.mbst.tv/render/?format=json&target=#{s[:graphiteId]}&from=-#{minsToGraph}minutes")
    begin
      graphiteJson = Net::HTTP.get(uri)
      graphiteData = JSON.parse(graphiteJson)[0]['datapoints']
    rescue
      STDERR.puts "Failed to fetch #{uri}"
      next
    end

    points = graphiteData.map do |p|
      # pointTime = Time.at(p[1]).to_datetime
      # timeDiff = pointTime - now
      # diffMinutes = (timeDiff * 24 * 60).round
      #
      # in fact dashing's default graph does its own weird time formatting, so we can just output the timestamps directly.

      { x: p[1], y: p[0] || 0 }
    end

    statsToAverage = graphiteData[-(minsToAverage)..-1].map{|p| p[0]}.compact
    average = statsToAverage.instance_eval { reduce(:+) / size.to_f }.round rescue 0

    send_event(s[:name], points: points, displayedValue: average)
  end
end