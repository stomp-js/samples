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
    end_point: 'integer-addition',
    amqp_conn: amqp_conn,
    thread_pool: thread_pool,
    subscribe_opts: {
        block: true,
        manual_ack: true
    }) do |delivery_info, metadata, payload|

  # simulate long running operation
  sleep rand(5000) / 1000.0

  # simulate failing requests
  if rand > 0.8
    raise RuntimeError, 'Not in a mood to process :)'
  end

  operands = JSON.parse(payload)
  result = {result: operands['x'].to_i + operands['y'].to_i}
  result.to_json
end
