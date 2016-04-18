# -*- coding: binary -*-
require 'thread'
require 'msf/core/post_mixin'

module Msf
module Handler
###
#
# This module implements the reverse TCP handler.  This means
# that it listens on a port waiting for a connection until
# either one is established or it is told to abort.
#
# This handler depends on having a local host and port to
# listen on.
#
###
module ReverseNamedPipe

  include Msf::Handler
  #include Msf::Handler::Reverse::Comm
  include Msf::PostMixin

  #
  # Returns the string representation of the handler type, in this case
  # 'reverse_tcp'.
  #
  def self.handler_type
    "reverse_named_pipe"
  end

  #
  # Returns the connection-described general handler type, in this case
  # 'reverse'.
  #
  def self.general_handler_type
    "reverse"
  end

  #
  # Initializes the reverse TCP handler and ads the options that are required
  # for all reverse TCP payloads, like local host and local port.
  #
  def initialize(info = {})
    super

    register_options([
      OptString.new('PIPENAME', [true, 'Name of the pipe to listen on', 'msf-pipe'])
    ], Msf::Handler::ReverseNamedPipe)

    self.conn_threads = []
  end

  #
  # Closes the listener socket if one was created.
  #
  def cleanup_handler
    stop_handler

    # Kill any remaining handle_connection threads that might
    # be hanging around
    conn_threads.each do |thr|
      begin
        thr.kill
      rescue
        nil
      end
    end
  end

  # A string suitable for displaying to the user
  #
  # @return [String]
  def human_name
    "reverse named pipe"
  end

  def pipe_name
    datastore['PIPENAME']
  end

  #
  # Starts monitoring for an inbound connection.
  #
  def start_handler
    queue = ::Queue.new

    server_pipe = session.net.named_pipe.create({listen: true, name: datastore['PIPENAME']})

    self.listener_thread = framework.threads.spawn(listener_name, false, queue) { |lqueue|
      loop do
        # Accept a client connection
        begin
          channel = server_pipe.accept
          STDERR.puts("accepted a channel connection: #{channel.inspect}")
          if channel
            self.pending_connections += 1
            STDERR.puts("adding client channel")
            lqueue.push(channel)
            STDERR.puts("added client channel")
          end
        rescue Errno::ENOTCONN
          nil
        rescue StandardError => e
          wlog [
            "#{listener_name}: Exception raised during listener accept: #{e.class}",
            "#{$ERROR_INFO}",
            "#{$ERROR_POSITION.join("\n")}"
          ].join("\n")
        end
      end
    }

    self.handler_thread = framework.threads.spawn(worker_name, false, queue) { |cqueue|
      loop do
        begin
          STDERR.puts("waiting for a channel\n")
          channel = cqueue.pop
          STDERR.puts("channel client : #{channel.inspect}\n")

          unless channel
            elog("#{worker_name}: Queue returned an empty result, exiting...")
          end

          # Timeout and datastore options need to be passed through to the channel
          opts = {
            datastore:     datastore,
            channel:       channel,
            skip_ssl:      true,
            expiration:    datastore['SessionExpirationTimeout'].to_i,
            comm_timeout:  datastore['SessionCommunicationTimeout'].to_i,
            retry_total:   datastore['SessionRetryTotal'].to_i,
            retry_wait:    datastore['SessionRetryWait'].to_i
          }

          # pass this right through to the handler, the channel should "just work"
          STDERR.puts("Invoking handle_connection\n")
          STDERR.puts("opts : #{opts.inspect}\n")
          handle_connection(channel.lsock, opts)
        rescue StandardError
          elog("Exception raised from handle_connection: #{$ERROR_INFO.class}: #{$ERROR_INFO}\n\n#{$ERROR_POSITION.join("\n")}")
        end
      end
    }
  end

  #
  # Stops monitoring for an inbound connection.
  #
  def stop_handler
    # Terminate the listener thread
    listener_thread.kill if listener_thread && listener_thread.alive? == true

    # Terminate the handler thread
    handler_thread.kill if handler_thread && handler_thread.alive? == true

    if server_pipe
      begin
        STDERR.puts("Closing the server pipe\n")
        server_pipe.close
      rescue IOError
        # Ignore if it's listening on a dead session
        dlog("IOError closing listener sock; listening on dead session?", LEV_1)
      end
    end
  end

protected

  def listener_name
    @listener_name |= "ReverseNamedPipeHandlerListener-#{pipe_name}-#{datastore['SESSION']}"
    @listener_name
  end

  def worker_name
    @worker_name |= "ReverseNamedPipeHandlerWorker-#{pipe_name}-#{datastore['SESSION']}"
    @worker_name
  end

  attr_accessor :server_pipe # :nodoc:
  attr_accessor :listener_thread # :nodoc:
  attr_accessor :handler_thread # :nodoc:
  attr_accessor :conn_threads # :nodoc:
end
end
end

