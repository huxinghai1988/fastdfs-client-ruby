require 'fastdfs-client/socket'
require 'fastdfs-client/cmd'
require 'fastdfs-client/proto_common'
require 'fastdfs-client/utils'
require 'tempfile'

module Fastdfs
  module Client

    class Storage
      include Utils

      attr_accessor :host, :port, :group_name, :store_path

      def initialize(host, port)
        @host = host
        @port = port
        @socket = Socket.new(host, port)
        @extname_len = ProtoCommon::EXTNAME_LEN
        @header_len = ProtoCommon::HEAD_LEN
        @size_len = ProtoCommon::SIZE_LEN
      end

      # File.open("/Users/huxinghai/Downloads/1279304.jpeg")
      # ext_name 6 byte
      # size_bytes 16 第一位是store_path_index
      # master_filename_bytes ISO8859-1
      # slave body size_byte + prefix_max_size(16) + ext_name(6) + master_filename_bytes + file_size
      # standard body size_byte + ext_name + file_size
      # cmd 11 
      # header = cmd + body_len  ... 11 ...29
      # write file bytes
      def upload(file)  
        case file

        when Tempfile
          _upload(file)
        when File
          _upload(file)
        when String

        else
          raise "data type exception #{file}"
        end
      ensure
        @socket.close
      end

      private 
      def _upload(file)
        cmd = CMD::UPLOAD_FILE

        extname = File.extname(file)[1..-1]
        ext_name_bs = extname.to_s.bytes.fill(0, extname.length...@extname_len)
        hex_len_bytes = long_convert_bytes(file.size)
        size_byte = [store_path].concat(hex_len_bytes).fill(0, (hex_len_bytes.length+1)...@size_len)
        hex_bytes = long_convert_bytes(size_byte.length + @extname_len + file.size)
        header = hex_bytes.fill(0, hex_bytes.length...@header_len)

        header[8] = cmd #cmd
        header[9] = 0   #erroron

        pkg = header + size_byte + ext_name_bs
        
        @socket.write(cmd, pkg.pack("C*"))
        @socket.write(cmd, IO.read(file))
        @socket.receive
        
        {group_name: pack_trim(@socket.content[0..15]), path: @socket.content[16..-1]}
      end

      
    end

  end
end