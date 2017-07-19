require 'optparse'
require 'fastly'
require 'pp'
require 'json'
require 'httparty'
require 'tty-spinner'

class FastlyApi
  include HTTParty
  base_uri 'https://api.fastly.com'.freeze
  # debug_output

  attr_reader :token, :service_id, :active_service_version
  attr_accessor :waf_id, :owasp_id

  def initialize(token, service_id, active_service_version)
    @token = token
    @service_id = service_id
    @active_service_version = active_service_version
  end

  def wafs
    endpoint = "/service/#{@service_id}/version/#{@active_service_version}/wafs"
    resp = self.class.get(endpoint, headers: headers)
    JSON.parse(resp.body)['data']
  end

  def owasp
    endpoint = "/service/#{@service_id}/wafs/#{@waf_id}/owasp"
    resp = self.class.get(endpoint, headers: headers)
    JSON.parse(resp.body)['data']
  end

  def update_owasp_threshold(threshold, value)
    endpoint = "/service/#{@service_id}/wafs/#{@waf_id}/owasp"
    resp = self.class.patch(
      endpoint,
      headers: headers('Content-Type' => 'application/vnd.api+json'),
      body: owasp_update_body(threshold, value)
    )
    JSON.parse(resp.body)['data']
  end

  def deploy_owasp_changes
    endpoint = "/service/#{@service_id}/wafs/#{@waf_id}/ruleset"
    resp = self.class.patch(
      endpoint,
      headers: headers('Content-Type' => 'application/vnd.api+json'),
      body: ruleset_update_body
    )
    JSON.parse(resp.body)
  end

  def update_status(endpoint)
    created = false
    spinner = TTY::Spinner.new('[:spinner] Updating Ruleset...', format: :dots, hide_cursor: true)
    spinner.auto_spin

    until created
      resp = JSON.parse(self.class.get(endpoint, headers: headers))

      status = resp.dig 'data', 'attributes', 'status'

      case status
      when 'complete'
        spinner.success('(Updated!)')
        created = true
      when 'failed'
        msg = resp.dig 'data', 'attributes', 'message'
        spinner.error("(Failed: #{msg})")
        break
      else # "in progress"
        sleep 1
        redo
      end

    end
  end

  private

  def headers(opts = {})
    opts.merge(
      'Fastly-Key' => @token,
      'Accept' => 'application/vnd.api+json'
    )
  end

  def owasp_update_body(threshold, value)
    {
      'data' => {
        'id' => @owasp_id,
        'type' => 'owasp',
        'attributes' => {
          threshold => value
        }
      }
    }.to_json
  end

  def ruleset_update_body
    {
      'data' =>  {
        'type' => 'ruleset',
        'id' => @waf_id,
        'attributes' => {}
      }
    }.to_json
  end
end

# Command line with Option Parse
flags = %i[api_token service_id]
options = Struct.new('Options', *flags) do
  def output
    puts "API-Key: #{api_token}"
    puts "Service-ID: #{service_id}"
  end

  def validate!
    raise 'API Key is required!' unless api_token
    raise 'Service ID is required!' unless service_id
  end
end.new

OptionParser.new do |opts|
  opts.banner = "USAGE: #{$PROGRAM_NAME} [options]"

  opts.on('-h', '--help', 'Help Menu') do
    puts opts
    exit
  end

  opts.on('-a', '--api-token TOKEN', 'Fastly api-token') do |a|
    options.api_token = a
  end

  opts.on('-s', '--service-id ID', 'service ID') do |s|
    options.service_id = s
  end
end.parse!

options.validate!
options.output

fastly = Fastly.new api_key: options.api_token

# Get active version of service
service = fastly.get_service(options.service_id)
active_version = service.versions.select(&:active).first.number
puts "Version: #{active_version}"

fastly_api = FastlyApi.new options.api_token, options.service_id, active_version

# Get the waf_id
wafs = fastly_api.wafs
fastly_api.waf_id = wafs.first['id']
puts fastly_api.waf_id

# Get the OWASP id and thresholds
owasp = fastly_api.owasp
fastly_api.owasp_id = owasp['id']
puts fastly_api.owasp_id

all_owasp_thresholds = owasp['attributes'].select { |k| k =~ /threshold$/ }
owasp_thresholds_to_update = all_owasp_thresholds.reject { |_k, v| v.to_i >= 999 }
puts

# update OWASP thresholds
owasp_thresholds_to_update.each_pair do |threshold, value|
  new_value = value + 30
  response = fastly_api.update_owasp_threshold threshold, new_value
  puts "Updated #{threshold} to #{response['attributes'][threshold]} (was #{value})"
end

response = fastly_api.deploy_owasp_changes
fastly_api.update_status response['links']['related']['href']
