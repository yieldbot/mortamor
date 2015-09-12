#! /usr/bin/env ruby
#
# this will take json and put it into elasticsearch for longterm storage
#
#

class DetailedMailer < Sensu::Handler
  def handle
    data = @event['check']

    File.open('/tmp/matty', 'w') do |f|
      f.write(data)
    end

    `curl -XPUT "http://localhost:9200/sensu/?pretty" -d data`
  end
end
