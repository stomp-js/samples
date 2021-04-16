require 'bundler/setup'
require 'bunny'
require 'json'

###############################################################################
# This demonstrates a minimal RPC server implemented in Ruby using AMQP
# through bunny.
#
# The key part is sending the response back through default exchange to the
# reply queue with appropriate correlation_id
#
# This may suffice for many use cases.
#
# For a more robust implementation please see rpc-helper.rb and
# rpc-server-thread-pool.rb
###############################################################################

amqp_conn = Bunny.new
amqp_conn.start

channel = amqp_conn.create_channel

# Notice that RabbitMQ STOMP adaptor maps queue/exchange names
queue = channel.queue("integer-addition")

queue.subscribe(block: true) do |delivery_info, metadata, payload|
  puts "Received: #{payload}"

  # Process the request, compute the response
  operands = JSON.parse(payload)
  result = { result: operands['x'].to_i + operands['y'].to_i }
  response_body = result.to_json
  # Completed processing

  puts "RPC Server: Response: #{response_body} for #{payload}"

  default_exchange = channel.default_exchange

  reply_to = metadata[:reply_to]

  # if the RPC client uses explicit queue name for replies, it needs to be translated from STOMP
  # semantics to AMQP. In this just removing the prefix /queue/ is sufficient
  # See https://www.rabbitmq.com/stomp.html#d for details
  reply_to = reply_to.sub(%r{^/queue/}, '')

  puts "Sent with routing key: #{reply_to}"
  default_exchange.publish response_body, routing_key: reply_to, correlation_id: metadata[:correlation_id]
end
