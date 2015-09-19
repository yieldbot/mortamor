# Truncate check output. For metric checks, (`"type":
# "metric"`), check output is truncated to a single line and a
# maximum of 255 characters. Check output is currently left
# unmodified for standard checks.
#
# @param check [Hash]
# @return [Hash] check with truncated output.
def truncate_check_output(check)
  case check[:type]
  when 'metric'
    output_lines = check[:output].split("\n")
    output = output_lines.first || check[:output]
    if output_lines.size > 1 || output.length > 255
      output = output[0..255] + "\n..."
    end
    check.merge(output: output)
  else
    check
  end
      end

# Store check result data. This method stores check result data
# and the 21 most recent check result statuses for a client/check
# pair, this history is used for event context and flap detection.
# The check execution timestamp is also stored, to provide an
# indication of how recent the data is. Check output is
# truncated by `truncate_check_output()` before it is stored.
#
# @param client [Hash]
# @param check [Hash]
# @param callback [Proc] to call when the check result data has
#   been stored (history, etc).
def store_check_result(client, check, &callback)
  @logger.debug('storing check result', check: check)
  @redis.sadd("result:#{client[:name]}", check[:name])
  result_key = "#{client[:name]}:#{check[:name]}"
  check_truncated = truncate_check_output(check)
  @redis.set("result:#{result_key}", MultiJson.dump(check_truncated)) do
    history_key = "history:#{result_key}"
    @redis.rpush(history_key, check[:status]) do
      @redis.ltrim(history_key, -21, -1)
      callback.call
    end
  end
end

# Update the event registry, stored in Redis. This method
# determines if check data results in the creation or update of
# event data in the registry. Existing event data for a
# client/check pair is fetched, used in conditionals and the
# composition of the new event data. If a check `:status` is not
# `0`, or it has been flapping, an event is created/updated in
# the registry. If there was existing event data, but the check
# `:status` is now `0`, the event is removed (resolved) from the
# registry. If the previous conditions are not met, and check
# `:type` is `metric` and the `:status` is `0`, the event
# registry is not updated, but the provided callback is called
# with the event data. All event data is sent to event bridge
# extensions, including events that do not normally produce an
# action. JSON serialization is used when storing data in the
# registry.
#
# @param client [Hash]
# @param check [Hash]
# @param callback [Proc] to be called with the resulting event
#   data if the event registry is updated, or the check is of
#   type `:metric`.
def update_event_registry(client, check, &callback)
  @redis.hget("events:#{client[:name]}", check[:name]) do |event_json|
    stored_event = event_json ? MultiJson.load(event_json) : nil
    flapping = check_flapping?(stored_event, check)
    event = {
      id: random_uuid,
      client: client,
      check: check,
      occurrences: 1,
      action: (flapping ? :flapping : :create),
      timestamp: Time.now.to_i
    }
    if check[:status] != 0 || flapping
      if stored_event && check[:status] == stored_event[:check][:status]
        event[:occurrences] = stored_event[:occurrences] + 1
      end
      @redis.hset("events:#{client[:name]}", check[:name], MultiJson.dump(event)) do
        callback.call(event)
      end
    elsif stored_event
      event[:occurrences] = stored_event[:occurrences]
      event[:action] = :resolve
      unless check[:auto_resolve] == false && !check[:force_resolve]
        @redis.hdel("events:#{client[:name]}", check[:name]) do
          callback.call(event)
        end
      end
    elsif check[:type] == 'metric'
      callback.call(event)
    end
    event_bridges(event)
  end
end
