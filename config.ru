$Credentials = YAML.load_file(File.join(File.expand_path(File.dirname(__FILE__)), 'credentials.yml'))
  # TODO use this instead maybe: https://github.com/binarylogic/settingslogic

require 'dashing'
require 'yaml'

configure do
  set :auth_token, 'YOUR_AUTH_TOKEN'
  set :default_dashboard, 'main'

  helpers do
    def protected!
     # Put any authentication code you want in here.
     # This method is run before accessing any resource.
    end
  end
end

map Sinatra::Application.assets_prefix do
  run Sinatra::Application.sprockets
end

run Sinatra::Application
