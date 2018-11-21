require 'logger'

###############################################################################
# A sophisticated RPC server framework.
#
# It supports the following:
#
# * You can pass a thread_pool which is instance of `Thread.pool` provided
#   by gem `thread`.
# * If you set `manual_ack` in `subscribe_opts`, it will take care of
#   `ack` for successful response. In case of any Exceptions, it will `reject`.
# * It supports `logger`, you can pass an instance to customize logging.
# * It should be considered production ready, please raise issues if you
#   find any cases which are not covered.
#
# See rpc-server-thread-pool.rb for usage sample
###############################################################################

class RPCHelper
  def self.serve(opts = {}, &compute)
    end_point = opts[:end_point]
    amqp_conn = opts[:amqp_conn]
    thread_pool = opts[:thread_pool]
    logger = opts[:logger] || Logger.new(STDERR)
    subscribe_opts = opts[:subscribe_opts] || {}

    use_thread_pool = (!!thread_pool)
    manual_ack = subscribe_opts[:manual_ack]

    main_channel = amqp_conn.create_channel
    queue = main_channel.queue(end_point)

    # to serialize ack/rejects on the channel
    mutex = Mutex.new

    # This has been factored out to support usage with and without a thread pool
    processor = lambda do |delivery_info, metadata, payload|
      begin
        logger.debug "Received: #{payload}"

        # Channel is not guaranteed to be thread safe
        # We must open a new channel when using thread pool
        private_channel = use_thread_pool ? amqp_conn.create_channel : main_channel
        default_exchange = private_channel.default_exchange

        publish_helper = PublishHelper.new(default_exchange,
                                           logger,
                                           metadata[:reply_to],
                                           metadata[:correlation_id])

        response_body = compute.call(delivery_info, metadata,
                                     payload, publish_helper)

        logger.debug "RPC Server: Response: #{response_body} for #{payload}"

        publish_helper.publish response_body

        if manual_ack
          # ack/reject must be called through the channel which received the message
          # Channel is not guaranteed to be thread safe, so mutex
          mutex.synchronize do
            # Second parameter tells only this message is acknowledged
            # (instead of all unacknowledged messages till now)
            main_channel.acknowledge(delivery_info.delivery_tag, false)
          end
        end
      rescue StandardError => exception
        logger.error exception

        if manual_ack
          # ack/reject must be called through the channel which received the message
          # Channel is not guaranteed to be thread safe, so mutex
          mutex.synchronize do
            # The second parameter request the broker to requeue the message
            main_channel.reject(delivery_info.delivery_tag, true)
          end
        end

        private_channel.close if use_thread_pool && private_channel
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

  class PublishHelper
    def initialize(exchange, logger, reply_to, correlation_id)
      @exchange = exchange
      @reply_to = reply_to
      @correlation_id = correlation_id
      @logger = logger
    end

    def publish(response_body)
      # @logger.debug response_body
      @exchange.publish response_body,
                        routing_key: @reply_to,
                        correlation_id: @correlation_id
    end
  end
end
