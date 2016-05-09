# -*- coding: binary -*-

require 'thread'
require 'rex/post/meterpreter/channel'
require 'rex/post/meterpreter/channels/stream'
require 'rex/post/meterpreter/extensions/stdapi/tlv'

module Rex
module Post
module Meterpreter
module Extensions
module Stdapi
module Net
module SocketSubsystem

###
#
# This class represents a logical named pipe client connection
# that is established from the remote machine and tunnelled
# through the established meterpreter connection, similar to an
# SSH port forward.
#
###
class NamedPipeClientChannel < Rex::Post::Meterpreter::Stream

  ##
  #
  # Factory
  #
  ##

  #
  # Opens a named pipe client channel using the supplied parameters.
  #
  def NamedPipeClientChannel.open(client, params)
    c = Channel.create(client, 'stdapi_net_named_pipe_client', self, CHANNEL_FLAG_SYNCHRONOUS,
      [
        { 'type'  => TLV_TYPE_PEER_HOST, 'value' => params.peerhost },
        { 'type'  => TLV_TYPE_PEER_PORT, 'value' => params.peerport },
        { 'type'  => TLV_TYPE_LOCAL_HOST, 'value' => params.localhost },
        { 'type'  => TLV_TYPE_LOCAL_PORT, 'value' => params.localport },
        { 'type'  => TLV_TYPE_CONNECT_RETRIES, 'value' => params.retries }
      ])
    c.params = params
    c
  end

  ##
  #
  # Constructor
  #
  ##

  #
  # Passes the channel initialization information up to the base class.
  #
  def initialize(client, cid, type, flags, pipe_name)
    super(client, cid, type, flags)

    lsock.extend(SocketInterface)
    lsock.extend(DirectChannelWrite)
    lsock.channel = self

    rsock.extend(SocketInterface)
    rsock.channel = self

    lsock.initinfo("Pipe (#{pipe_name})", "Session (#{client.tunnel_to_s})")
  end

  #
  # Closes the write half of the connection.
  #
  def close_write
    return shutdown(1)
  end

  #
  # Shutdown the connection
  #
  # 0 -> future reads
  # 1 -> future sends
  # 2 -> both
  #
  def shutdown(how = 1)
    request = Packet.create_request('stdapi_net_socket_named_pipe_shutdown')

    request.add_tlv(TLV_TYPE_SHUTDOWN_HOW, how)
    request.add_tlv(TLV_TYPE_CHANNEL_ID, self.cid)

    client.send_request(request)

    return true
  end

end

end; end; end; end; end; end; end


