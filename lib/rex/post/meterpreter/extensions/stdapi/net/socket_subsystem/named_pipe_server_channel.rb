# -*- coding: binary -*-
require 'timeout'
require 'thread'
require 'rex/post/meterpreter/channels/stream'
require 'rex/post/meterpreter/extensions/stdapi/tlv'
#require 'rex/post/meterpreter/extensions/stdapi/net/socket_subsystem/tcp_client_channel'

module Rex
module Post
module Meterpreter
module Extensions
module Stdapi
module Net
module SocketSubsystem

class NamedPipeServerChannel < Rex::Post::Meterpreter::Channel

  PIPE_ACCESS_INBOUND  = 0x01
  PIPE_ACCESS_OUTBOUND = 0x02
  PIPE_ACCESS_DUPLEX   = 0x03

  #
  # This is a class variable to store all pending client tcp connections which have not been passed
  # off via a call to the respective server tcp channels accept method. The dictionary key is the
  # tcp server channel instance and the values held are an array of pending tcp client channels
  # connected to the tcp server channel.
  #
  @@server_channels = {}

  #
  # This is the request handler which is registered to the respective meterpreter instance via
  # Rex::Post::Meterpreter::Extensions::Stdapi::Net::Socket. All incoming requests from the meterpreter
  # for a 'tcp_channel_open' will be processed here. We create a new TcpClientChannel for each request
  # received and store it in the respective tcp server channels list of new pending client channels.
  # These new tcp client channels are passed off via a call the the tcp server channels accept() method.
  #
  def self.request_handler(client, packet)
    return false unless packet.method == "named_pipe_channel_open"

    cid       = packet.get_tlv_value( TLV_TYPE_CHANNEL_ID )
    pid       = packet.get_tlv_value( TLV_TYPE_CHANNEL_PARENTID )
    #localhost = packet.get_tlv_value( TLV_TYPE_LOCAL_HOST )
    #localport = packet.get_tlv_value( TLV_TYPE_LOCAL_PORT )
    #peerhost  = packet.get_tlv_value( TLV_TYPE_PEER_HOST )
    #peerport  = packet.get_tlv_value( TLV_TYPE_PEER_PORT )

    return false if cid.nil? || pid.nil?

    server_channel = client.find_channel(pid)

    return false if server_channel.nil?

    params = {
      #'LocalHost' => localhost,
      #'LocalPort' => localport,
      #'PeerHost'  => peerhost,
      #'PeerPort'  => peerport,
      'Comm'      => server_channel.client
    }

    client_channel = NamedPipeClientChannel.new(client, cid, NamedPipeClientChannel, CHANNEL_FLAG_SYNCHRONOUS)

    client_channel.params = params

    @@server_channels[server_channel] ||= ::Queue.new
    @@server_channels[server_channel].enq(client_channel)

    true
  end

  def self.cls
    CHANNEL_CLASS_STREAM
  end

  #
  # Open a new named pipe server channel on the remote end.
  #
  # @return [Channel]
  def self.open(client, params)
    # assume duplex unless specified otherwise
    open_mode = PIPE_ACCESS_DUPLEX
    if params[:open_mode]
      case params[:open_mode]
      when :inbound
        open_mode = PIPE_ACCESS_INBOUND
      when :outbound
        open_mode = PIPE_ACCESS_INBOUND
      end
    end

    c = Channel.create(client, 'stdapi_net_named_pipe_server', self, CHANNEL_FLAG_SYNCHRONOUS,
      [
        {'type'=> TLV_TYPE_NAMED_PIPE_SERVER,    'value' => params[:server] || '.'},
        {'type'=> TLV_TYPE_NAMED_PIPE_NAME,      'value' => params[:name]},
        {'type'=> TLV_TYPE_NAMED_PIPE_OPEN_MODE, 'value' => open_mode},
        {'type'=> TLV_TYPE_NAMED_PIPE_PIPE_MODE, 'value' => params[:pipe_mode] || 0},
        {'type'=> TLV_TYPE_NAMED_PIPE_COUNT,     'value' => params[:count] || 0},
      ] )
    c.params = params
    c
  end

  #
  # Simply initilize this instance.
  #
  def initialize(client, cid, type, flags)
    super(client, cid, type, flags)
    # add this instance to the class variables dictionary of tcp server channels
    @@server_channels[self] ||= ::Queue.new
  end

  #
  # Accept a new tcp client connection form this tcp server channel. This method does not block
  # and returns nil if no new client connection is available.
  #
  def accept_nonblock
    _accept(true)
  end

  #
  # Accept a new tcp client connection form this tcp server channel. This method will block indefinatly
  # if no timeout is specified.
  #
  def accept(opts = {})
    timeout = opts['Timeout']
    if (timeout.nil? || timeout <= 0)
      timeout = 0
    end

    result = nil
    begin
      ::Timeout.timeout(timeout) {
        result = _accept
      }
    rescue Timeout::Error
    end

    result
  end

protected

  def _accept(nonblock = false)
    result = nil

    channel = @@server_channels[self].deq(nonblock)

    if channel
      result = channel.lsock
    end

    if result != nil && !result.kind_of?(Rex::Socket::Tcp)
      result.extend(Rex::Socket::Tcp)
    end

    result
  end

end

end; end; end; end; end; end; end


