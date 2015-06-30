require 'net/http'
require 'json'

JENKINS_URI = $Credentials['jenkins']['url']

JENKINS_AUTH = {
  name: $Credentials['jenkins']['username'],
  password: $Credentials['jenkins']['password']
}

SCHEDULER.every '20s' do
  failedJobs = []
  unstableJobs = []
  abortedJobs = []

  begin
    json = getFromJenkins(JENKINS_URI + 'api/json?pretty=true')
    json['jobs'].each do |job|
      next if job['name'] =~ /^deploy-/

      next if job['color'] == 'disabled'
      next if job['color'] == 'notbuilt'
      next if job['color'] == 'blue'
      next if job['color'] == 'blue_anime'

      jobStatus = nil;
      if job['color'] == 'yellow' || job['color'] == 'yellow_anime'
        unstableJobs.push({ name: job['name'] })
      elsif job['color'] == 'aborted'
        abortedJobs.push({ name: job['name'] })
      else
        failedJobs.push({ name: job['name'] })
      end
    end

    stuff = {
      failedJobs: failedJobs,
      unstableJobs: unstableJobs,
      abortedJobs: abortedJobs
    }
    send_event('jenkins-build-status', stuff)
  rescue
    STDERR.puts "Couldn't fetch jenkins status :(."
    STDERR.puts $!, *$@
  end
end

def getFromJenkins(path)
  uri = URI.parse(path)
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Get.new(uri.request_uri)
  if JENKINS_AUTH[:name]
    request.basic_auth(JENKINS_AUTH[:name], JENKINS_AUTH[:password])
  end
  response = http.request(request)

  json = JSON.parse(response.body)
  return json
end
