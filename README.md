# stompjs and rx-stomp Samples

These simples demonstrate usage of https://github.com/stomp-js/stompjs
family of libraries.

To run these samples you would need a STOMP broker running locally.

These samples should work out of the box with a fresh RabbitMQ installation
with plugin `rabbitmq_web_stomp` enabled.

## stompjs

- [Level - Introductory] A very [simple chat application](stompjs/chat/chat.html).

## rx-stomp

- [Level - Introductory] A very [simple rx-chat application](rx-stomp/chat/rx-chat.html).

## Remote Procedure Call

These are implemented using `rx-stomp` and can be used with `ng2-stompjs`.

### Simple RPC

This demonstrates [RxStompRPC#rpc].

See the client at:

- [rpc/simple/rx-rpc.html](rpc/simple/rx-rpc.html).
- Click the button `Submit Problem` many times to see each one getting submitted
  as independent requests.
- There is an alternate client sample at 
  [rpc/simple/rx-rpc-explicit-return-dest.html](rpc/simple/rx-rpc-explicit-return-dest.html).
  This uses custom reply queue. This client is only tested with the simple ruby server.

You will need to run at least one of the following servers:

- [rpc/simple/rx-rpc-server.html](rpc/simple/rx-rpc-server.html) - this server
  simulates a random delay in response. This can be considered a minimal RPC
  server.
- [rpc/ruby-server/simple-server.rb](rpc/ruby-server/simple-server.rb) is a minimalistic
  server. Conceptually does similar to the JavaScript version. It is single threaded,
  blocking server.
- [rpc/ruby-server/server-thread-pool.rb](rpc/ruby-server/server-thread-pool.rb) demonstrates
  a small framework that separates out boilerplate part in writing server. See:
  [rpc/ruby-server/rpc-helper.rb](rpc/ruby-server/rpc-helper.rb).
  It shows Thread pooling, manual acknowledgements, simulated time taking operations.

Considering what it delivers, the code as a whole is quite simple.
There are more things to observe:

- These examples support load balancing - start multiple servers and see that RabbitMQ
  will load balance across those.
- If you are using [rpc/ruby-server/server-thread-pool.rb](rpc/ruby-server/server-thread-pool.rb)
  you can observe that in case of failures the request is retried.
- The scheme can be implemented in any language.
- Load balancing works across different flavors of servers.
- When you start a client with no active servers, the requests will be queued till a server
  comes online and processes it. This can be controlled using TTL (time to live) capabilities
  of RabbitMQ.
  
If you are planning to use this in production you might consider using
[rpc/ruby-server/server-thread-pool.rb](rpc/ruby-server/server-thread-pool.rb)
as your base.

### Streaming RPC

This demonstrates [RxStompRPC#stream].

It extends the previous example, however allows multiple responses to be sent from
the server to the client.
This examples uses this capability to communicate progress status.

See the client at:

- [rpc/stream/rx-rpc-with-progress.html](rpc/stream/rx-rpc-with-progress.html).
- Click the button `Submit Problem` many times to see each one getting submitted
  as independent requests.
- It makes clever use of RxJS operators to keep the code for progress and
  actual result separate.
- This closes the observable once final results have arrived.

See the server at:

- [rpc/ruby-server/stream-server-thread-pool.rb](rpc/ruby-server/stream-server-thread-pool.rb)
  is an extended version of the example above. It uses the same framework
  [rpc/ruby-server/rpc-helper.rb](rpc/ruby-server/rpc-helper.rb).

### Ruby servers

- These use `bunny` to communicate which uses AMQP.
- These have been tested with Ruby 2.5.
- You need to install dependencies by running `bundle install` in folder `rpc/ruby-server`.
- Start the server by running `bundle exec ruby <script-name>`.

## References

- Guides at https://stomp-js.github.io/
- API documents at: https://stomp-js.github.io/api-docs/latest/


[RxStompRPC#rpc]: https://stomp-js.github.io/api-docs/latest/classes/RxStompRPC.html#rpc
[RxStompRPC#stream]: https://stomp-js.github.io/api-docs/latest/classes/RxStompRPC.html#stream
