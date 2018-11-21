require 'logger'

class RPCHelper
  def self.serve(opts = {}, &compute)
    end_point = opts[:end_point]
    amqp_conn = opts[:amqp_conn]
    thread_pool = opts[:thread_pool]
    logger = opts[:logger] || Logger.new(STDERR)
    subscribe_opts = opts[:subscribe_opts] || {}

    use_thread_pool = (!!thread_pool)

    channel = amqp_conn.create_channel
    queue = channel.queue(end_point)

    processor = lambda do |delivery_info, metadata, payload|
      logger.debug "Received: #{payload}"

      response_body = compute.call(delivery_info, metadata, payload)

      logger.debug "RPC Server: Response: #{response_body} for #{payload}"

      # Channel is not guaranteed to be thread safe
      # Since we are in another thread, we must open a new channel
      private_channel = amqp_conn.create_channel
      default_exchange = private_channel.default_exchange

      default_exchange.publish response_body,
                               routing_key: metadata[:reply_to],
                               correlation_id: metadata[:correlation_id]
      private_channel.close
    end

    queue.subscribe(subscribe_opts) do |delivery_info, metadata, payload|
      if use_thread_pool
        thread_pool.process do
          processor.call(delivery_info, metadata, payload)
        end
      else
        processor.call(delivery_info, metadata, payload)
      end
    end
  end
end
