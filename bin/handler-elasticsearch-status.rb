#!/usr/bin/env ruby
#
# Sensu Elasticsearch Metrics Handler

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'net/http'
require 'timeout'
require 'digest/md5'
require 'date'

class ElasticsearchMetrics < Sensu::Handler
  def acquire_setting(name)
    product = ARGV[0]
    settings[product][name]
  end

  # def es_host
  #   product = ARGV[0]
  #   settings[product]['elasticsearch']['host'] || 'localhost'
  # end

  # def es_port
  #   settings['elasticsearch']['port'] || 9200
  # end

  # def calc_date
  #   ts = @event['client']['timestamp']
  #   ts.utch
  # end

  # def es_index
  #   settings['elasticsearch']['index'] || 'monitoring-status'
  # end

  #   def es_id
  #     rdm = ((0..9).to_a + ("a".."z").to_a + ("A".."Z").to_a).sample(3).join
  #     Digest::MD5.new.update("#{rdm}")
  #   end

  #   def time_stamp
  #     d = DateTime.now
  #     d.to_s
  #   end

  def event_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  # def es_type
  #   if @event['check']['elasticsearch']
  #     data = @event['check']['elasticsearch']
  #     "#{data['source']}-#{data['location']}-#{data['type']}"
  #   else
  #     puts 'Elasticsearch index path not found'
  #     exit(127)
  #   end
  # end

  # def service_output
  #   out = JSON.parse(@event['[check']['output'])
  #   service = out['service']
  #   status = out['status']
  # end

  def handle
    # data = {
    #   timestamp: calc_date,
    #   client: @event['client']['name'],
    #   check_name: @event['check']['name'],
    #   status: @event['check']['status'],
    #   address: @event['client']['address'],
    #   command: @event['check']['command'],
    #   occurrences: @event['occurrences'],
    #   output: @event['output']
    # }

    timeout(5) do
      host   = acquire_setting(host)
      port   = acquire_setting(port)
      index  = acquire_setting(index)

      uri           = URI("http://#{host}:#{port}/#{index}")
      http          = Net::HTTP.new(uri.host, uri.port)
      request       = Net::HTTP::Post.new(uri.path, 'content-type' => 'application/json; charset=utf-8')
      request.body  = JSON.dump(@event)
      response      = http.request(request)

      if response.code =~ '200|201'
        puts "request data #=> #{@event}"
        puts "request body #=> #{response.body}"
        puts 'elasticsearch post ok.'
      else
        puts "request data #=> #{@event}"
        puts "request body #=> #{response.body}"
        puts "elasticsearch post failure. status error code #=> #{response.code}"
      end
    end
  rescue Timeout::Error
    puts 'elasticsearch timeout error.'
  end
end
