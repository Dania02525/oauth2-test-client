require 'bundler'
require 'json'

PKCE_VERIFIER_LENGTH = 48

Bundler.require

enable :sessions

get '/' do
  @oauth_server_url ||= 'http://localhost:3000'
  session[:redirect_url] = File.join(request.base_url, 'callback', 'oauth')
  session[:pkce_verifier] = SecureRandom.base64((PKCE_VERIFIER_LENGTH * 3) / 4).tr("+/", "-_").tr("=", "")
  @redirect_url = session[:redirect_url]
  erb :index
end

post '/' do
  session[:client_id] = params['client_id']
  session[:client_secret] = params['client_secret']
  session[:oauth_server_url] = params['oauth_server_url']
  session[:account_token] = params['account_token']

  client = OAuth2::Client.new(session[:client_id], session[:client_secret], site: session[:oauth_server_url])
  args = {
    redirect_uri: session[:redirect_url],
    scope: 'public',
    code_challenge: Digest::SHA256.base64digest(session[:pkce_verifier]).tr("+/", "-_").tr("=", ""),
    code_challenge_method: 'S256'
  }
  location = client.auth_code.authorize_url(args)
  redirect location
end

get '/callback/oauth' do
  code = params['code']
  client = OAuth2::Client.new(session[:client_id], session[:client_secret], site: session[:oauth_server_url])
  args = {
    redirect_uri: session[:redirect_url],
    code_verifier: session[:pkce_verifier],
    code_challenge_method: 'S256'
  }
  session[:access_token] = client.auth_code.get_token(code, args).to_hash
  redirect '/vehicles'
end

get '/vehicles' do
  client = OAuth2::Client.new(session[:client_id], session[:client_secret], site: session[:oauth_server_url])
  token = OAuth2::AccessToken.from_hash(client, session[:access_token])
  headers = {
    'Account-Token' => session[:account_token]
  }
  response = token.get(File.join(session[:oauth_server_url], 'api', 'vehicles'), headers: headers)
  @vehicles = JSON.parse(response.body).fetch('records')
  erb :vehicles
end
