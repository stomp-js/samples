require 'logger'

class RPCHelper
  def self.serve(opts = {}, &compute)
    end_point = opts[:end_point]
    amqp_conn = opts[:amqp_conn]
    thread_pool = opts[:thread_pool]
    logger = opts[:logger] || Logger.new(STDERR)
    subscribe_opts = opts[:subscribe_opts] || {}

    use_thread_pool = (!!thread_pool)
    manual_ack = subscribe_opts[:manual_ack]

    channel = amqp_conn.create_channel
    queue = channel.queue(end_point)

    # to serialize ack/rejects on the channel
    mutex = Mutex.new

    processor = lambda do |delivery_info, metadata, payload|
      begin
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

        if manual_ack
          # ack/reject must be called through the channel which received the message
          # Channel is not guaranteed to be thread safe, so mutex
          mutex.synchronize do
            # Second parameter tells only this message is acknowledged
            # (instead of all unacknowledged messages till now)
            channel.acknowledge(delivery_info.delivery_tag, false)
          end
        end
      rescue StandardError => exception
        logger.error exception

        if manual_ack
          # ack/reject must be called through the channel which received the message
          # Channel is not guaranteed to be thread safe, so mutex
          mutex.synchronize do
            # The second parameter request the broker to requeue the message
            channel.reject(delivery_info.delivery_tag, true)
          end
        end

        private_channel.close if private_channel
      end
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
