#!/usr/bin/env ruby
#
# Sensu Elasticsearch Status Handler

require 'sensu-handler'
require 'net/http'
require 'timeout'
require 'date'

class ElasticsearchMetrics < Sensu::Handler
  def acquire_setting(name)
    product = ARGV[0]
    settings[product][name]
  end

  def event_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def acquire_monitored_instance
    @event['client']['name']
  end

  def acquire_infra_details
    JSON.parse(File.read('/etc/sensu/conf.d/monitoring_infra.json'))
  end

  def define_status(event)
    case event
    when 0
      return 'OK'
    when 1
      return 'WARNING'
    when 2
      return 'CRITICAL'
    when 3
      return 'UNKNOWN'
    when 127
      return 'CONFIG ERROR'
    when 126
      return 'PERMISSION DENIED'
    else
      return 'ERROR'
    end
  end

  def define_sensu_env
    case acquire_infra_details['sensu']['environment']
    when 'prd'
      return 'Prod '
    when 'dev'
      return 'Dev '
    when 'stg'
      return 'Stg '
    when 'vagrant'
      return 'Vagrant '
    else
      return 'Test '
    end
  end

  def create_check_name(name)
    name.split('-').reverse.inject() { |a, n| { n => a } }
  end

  def define_check_state_duration
    ''
  end

  def check_data
    ''
  end

  def handle
    data = {
      'monitored_instance'    => acquire_monitored_instance, # this will be the snmp host if using traps
      'sensu_client'          => @event['client']['name'],
      'incident_timestamp'    => Time.at(@event['check']['issued']),
      'instance_address'      => @event['client']['address'],
      'check_name'            => create_check_name(@event['check']['name']),
      'check_state'           => define_status(@event['check']['status']),
      'check_data'            => check_data, # any additional user supplied data
      'sensu_env'             => define_sensu_env.chop!,
      'check_state_duration'  => define_check_state_duration
    }

    timeout(5) do
      host   = acquire_setting('host')
      port   = acquire_setting('port')
      index  = acquire_setting('index')
      id     = "#{@event['client']['name']}_#{@event['check']['name']}"

      uri           = URI("http://#{host}:#{port}/#{index}/dashboard/#{id}")
      http          = Net::HTTP.new(uri.host, uri.port)
      request       = Net::HTTP::Post.new(uri.path, 'content-type' => 'application/json; charset=utf-8')
      request.body  = JSON.dump(data)
      response      = http.request(request)

      if /200|201/ =~ response.code
        puts "request data #=> #{data}"
        puts "request body #=> #{response.body}"
        puts 'elasticsearch post ok.'
      else
        puts "request data #=> #{data}"
        puts "request body #=> #{response.body}"
        puts "elasticsearch post failure. status error code #=> #{response.code}"
      end
    end
  rescue Timeout::Error
    puts 'elasticsearch timeout error.'
  end
end
