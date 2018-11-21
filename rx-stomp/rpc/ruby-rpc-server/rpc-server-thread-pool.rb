require 'bundler/setup'
require 'bunny'
require 'json'
require 'thread/pool'
require 'logger'

require_relative 'rpc-helper'

pool = Thread.pool(3)

conn = Bunny.new
conn.start

RPCHelper.serve_with_pool(
    end_point: 'integer-addition',
    conn: conn,
    pool: pool,
    subscribe_opts: {block: true}) do |delivery_info, metadata, payload|

  sleep rand(5000) / 1000.0
  operands = JSON.parse(payload)
  result = {result: operands['x'].to_i + operands['y'].to_i}
  result.to_json
end
