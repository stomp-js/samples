require 'logger'

class RPCHelper
  def self.serve_with_pool(opts = {}, &compute)
    end_point = opts[:end_point]
    conn = opts[:conn]
    pool = opts[:pool]
    logger = opts[:logger] || Logger.new(STDERR)
    subscribe_opts = opts[:subscribe_opts] || {}

    channel = conn.create_channel
    queue = channel.queue(end_point)

    queue.subscribe(subscribe_opts) do |delivery_info, metadata, payload|
      pool.process do
        logger.debug "Received: #{payload}"

        response_body = compute.call(delivery_info, metadata, payload)

        logger.debug "RPC Server: Response: #{response_body} for #{payload}"

        # Channel is not guaranteed to be thread safe
        # Since we are in another thread, we must open a new channel
        private_channel = conn.create_channel
        default_exchange = private_channel.default_exchange

        default_exchange.publish response_body,
                                 routing_key: metadata[:reply_to],
                                 correlation_id: metadata[:correlation_id]
        private_channel.close
      end
    end
  end
end
