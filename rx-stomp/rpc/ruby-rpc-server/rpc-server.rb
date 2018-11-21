require 'bundler/setup'
require 'bunny'
require 'json'

conn = Bunny.new
conn.start

ch = conn.create_channel
q = ch.queue("integer-addition")

q.subscribe(block: true) do |delivery_info, metadata, payload|
  puts "Received: #{payload}"
  # Process the request, compute the response
  operands = JSON.parse(payload)
  result = {result: operands['x'].to_i + operands['y'].to_i}
  response_body = result.to_json
  # Completed processing

  puts "RPC Server: Response: #{response_body} for #{payload}"

  x = ch.default_exchange

  x.publish response_body, routing_key: metadata[:reply_to], correlation_id: metadata[:correlation_id]
end
