module System
  attach_function nil, "strerror", :strerror, [:int], :string
  attach_function nil, "ffi_errno", :errno, [], :int
  
  def self.error
    strerror(self.errno)
  end
end

module Errno
  def self.handle(msg=nil)
    err = System.errno
    return unless err != 0
    
    exc = Errno::Mapping[err]
    if exc
      if msg
        msg = "#{msg} (#{System.error})"
      else
        msg = System.error
      end
      raise exc.new(msg, err)
    else
      raise "Unknown error: #{System.error} (#{err})"
    end
  end
end

class Socket < IO
    
  module Constants
    AF_UNIX =   1
    AF_LOCAL =  1
    AF_INET =   2
    
    SOCK_STREAM = 1
    SOCK_DGRAM =  2
    SOCK_RAW =    3
    SOCK_RDM =    4
    SOCK_SEQPACKET = 5

    AI_PASSIVE = 1
  end
  
  module Foreign
    attach_function nil, "socket", :create_socket, [:int, :int, :int], :int
    attach_function nil, "ffi_pack_sockaddr_un", :pack_sa_unix, [:state, :string], :object
    attach_function nil, "ffi_pack_sockaddr_in", :pack_sa_ip,   [:state, :string, :string, :int, :int], :object
    attach_function nil, "connect", :connect_socket, [:int, :pointer, :int], :int
    attach_function nil, "bind", :bind_socket, [:int, :pointer, :int], :int
    attach_function nil, "listen", :listen_socket, [:int, :int], :int
    attach_function nil, "ffi_bind_local_socket", :bind_local_socket, [:int], :int
    attach_function nil, "accept", :accept, [:int, :pointer, :pointer], :int
  end
  
  def initialize(domain, type, protocol)
    fd = Foreign.create_socket(domain.to_i, type.to_i, protocol.to_i)
    if fd < 0
      raise "Unable to create socket"
    end
    
    super(fd)
    
    @domain = domain
    @type = type
    @protocol = protocol
  end
  
end

class UNIXSocket < Socket
    
  def initialize(path)
    super(Socket::Constants::AF_UNIX, Socket::Constants::SOCK_STREAM, 0)
    @path = path
  end
end

class UNIXServer < UNIXSocket
  
end

class IPSocket < Socket
  def initialize(kind, protocol=0)
    super(Socket::Constants::AF_INET, kind, protocol)
  end
end

class TCPSocket < IPSocket
  ivar_as_index :descriptor => 1
  def descriptor=(other)
    @descriptor = other
  end
  
  def initialize(host, port, connected = false)
    unless connected
      super(Socket::Constants::SOCK_STREAM)
      @host = host
      @port = port


      @sockaddr, @sockaddr_size = Socket::Foreign.pack_sa_ip(host.to_s, port.to_s, @type, 0)
      sock = Socket::Foreign.connect_socket(descriptor, @sockaddr, @sockaddr_size) 
      if sock != 0
        Errno.handle "Unable to connect to #{host}:#{port}"
      end
    end
  end
  
  def inspect
    "#<#{self.class}:0x#{object_id.to_s(16)} #{@host}:#{@port}>"
  end
end

class TCPServer < TCPSocket
  ivar_as_index :descriptor => 1
  def initialize(host, port = nil)
    if host.kind_of?(Fixnum) then
      port = host
      host = '0.0.0.0' # TODO - Do this in a portable way
    end
    @host = host
    @port = port

    @domain = Socket::Constants::AF_INET
    @type = Socket::Constants::SOCK_STREAM
    @protocol = 0
    fd = Socket::Foreign.create_socket(@domain, @type, @protocol)
    if fd < 0
      Errno.handle "Unable to create socket"
    end
    @descriptor = fd

    @sockaddr, @sockaddr_size = Socket::Foreign.pack_sa_ip(@host.to_s, @port.to_s, @type, Socket::Constants::AI_PASSIVE)
    bind = Socket::Foreign.bind_socket(descriptor, @sockaddr, @sockaddr_size)
    if bind != 0
      Errno.handle "Unable to bind to #{@host}:#{@port}"
    end
    ret = Socket::Foreign.listen_socket(fd, 5)
    if ret != 0
      Errno.handle "Unable to listen on #{@host}:#{@port}"
    end
  end

  def accept
    return if closed?
    fd = -1
    size = 0
    MemoryPointer.new :int do |sz|
      sz.write_int @sockaddr_size # initialize to the 'expected' size
      fd = Socket::Foreign.accept @descriptor, @sockaddr, sz
      size = sz.read_int
    end
    if fd < 0
      Errno.handle "Unable to accept on socket"
    end

    socket = TCPSocket.new(@host, @port, true)
    socket.descriptor = fd

    socket
  end
end

