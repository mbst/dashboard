require 'faraday'
require 'json'
require 'pp'

url = $Credentials['api_errors']['logstash_url']
RelevantAtlasKeys = $Credentials['api_errors']['relevant_atlas_keys']

def extractStatusTypes(buckets)
  {
    client: buckets.select{|b| b['key'] =~ /4../}.map{|b| b['doc_count']}.inject(:+) || 0,
    server: buckets.select{|b| b['key'] =~ /5../}.map{|b| b['doc_count']}.inject(:+) || 0
  }
end

def atlasQuery(conn, timerange)
  res = JSON.parse(conn.post {|req|
    indices = [DateTime.now, DateTime.now-1].map{|dt| "logstash-atlas-access-#{dt.strftime('%Y.%m.%d')}"}.join(',')
    req.url "/#{indices}/_search?pretty=&search_type=count"
    req.headers['Content-type'] = 'application/json'
    req.body = JSON.generate({
      query: { bool: { must: [
        {terms: {
          "params.apiKey" => RelevantAtlasKeys
        }},
        {range: {
          "@timestamp" => { gte: timerange }
        }}
      ]}},
      aggs: {
        statuses: {
          terms: { field: "responseStatus", size: 0 }
        }
      }
    })
  }.body)
  extractStatusTypes res['aggregations']['statuses']['buckets']
end

def voilaQuery(conn, timerange)
  res = JSON.parse(conn.post {|req|
    indices = [DateTime.now, DateTime.now-1].map{|dt| "logstash-voila-access-#{dt.strftime('%Y.%m.%d')}"}.join(',')
    req.url "/#{indices}/_search?pretty=&search_type=count"
    req.headers['Content-type'] = 'application/json'
    req.body = JSON.generate({
      query: { range: {
          "@timestamp" => { gte: timerange }
      }},
      aggs: {
        statuses: {
          terms: { field: "responseStatus", size: 0 }
        }
      }
    })
  }.body)
  extractStatusTypes res['aggregations']['statuses']['buckets']
end

SCHEDULER.every '20s' do
    conn = Faraday.new(:url => "#{url}") do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
      faraday.headers['Content-type'] = 'application/json'
    end

    begin
      atlas_recent = atlasQuery(conn, "now-5m")
      atlas_baseline = atlasQuery(conn, "now-24h")
      voila_recent = voilaQuery(conn, "now-5m")
      voila_baseline = voilaQuery(conn, "now-24h")

      send = {
        server: {
          recent: Hash[ {
            atlas: atlas_recent[:server],
            voila: voila_recent[:server],
            both: atlas_recent[:server] + voila_recent[:server]
          }.map{|k, stat| [k, Rational(stat, 5).ceil]} ],
          baseline: Hash[ {
            atlas: atlas_baseline[:server],
            voila: voila_baseline[:server],
            both: atlas_baseline[:server] + voila_baseline[:server]
          }.map{|k, stat| [k, Rational(stat, 60*24).ceil]} ],
        },
        client: {
          recent: Hash[ {
            atlas: atlas_recent[:client],
            voila: voila_recent[:client],
            both: atlas_recent[:client] + voila_recent[:client]
          }.map{|k, stat| [k, Rational(stat, 5).ceil]} ],
          baseline: Hash[ {
            atlas: atlas_baseline[:client],
            voila: voila_baseline[:client],
            both: atlas_baseline[:client] + voila_baseline[:client]
          }.map{|k, stat| [k, Rational(stat, 60*24).ceil]} ],
        }
      }
      send_event("api-errors", send)

    rescue
      STDERR.puts "Couldn't fetch API error rate :(."
      STDERR.puts $!, *$@
    end
end
