require 'bundler/setup'
require 'bunny'
require 'json'
require 'thread/pool'
require 'logger'

require_relative 'rpc-helper'

thread_pool = Thread.pool(3)

amqp_conn = Bunny.new
amqp_conn.start

RPCHelper.serve(
    end_point: 'integer-addition-with-progress',
    amqp_conn: amqp_conn,
    thread_pool: thread_pool,
    subscribe_opts: {
        block: true,
        manual_ack: true
    }) do |delivery_info, metadata, payload, publish_helper|

  # simulate a long running task
  max = 50 + rand(100)
  current = 0

  while current < max
    sleep rand(500)/1000.0
    current += rand(30)
    current = max if current > max

    # Progress report, it needs to be a string
    publish_helper.publish({progress: {current: current, max: max}}.to_json)

    # simulate failing requests
    if rand > 0.95
      # An Exception indicates task was not completed, it will be retried
      raise RuntimeError, 'Not in a mood to process :)'
    end
  end

  operands = JSON.parse(payload)
  result = {result: operands['x'].to_i + operands['y'].to_i}

  # Return value from this block will be the final result of processing
  # It needs to be string
  result.to_json
end
