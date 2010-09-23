# need this just in case it hasn't been loaded yet
java.awt.datatransfer.DataFlavor

module Java
  module JavaAwtDatatransfer
    class DataFlavor
      def inspect
        "#<DataFlavor #{mime_type}>"
      end
      
      def simple_type
        mime_type.split('; ').first
      end
    end
  end
end

require 'io/like'

module Clevic

  class Stream
    def initialize( input_stream )
      @input_stream = input_stream
    end

    include IO::Like
    def unbuffered_read( length )
      nex = @input_stream.read
      raise EOFError if nex == -1
      
      begin
        (0...length).inject([nex]) do |buf,i|
          nex = @input_stream.read
          if nex == -1
            break( buf )
          else
            buf << nex
          end
        end.pack('c*')
      rescue
        raise SystemCallError, $!.message
      end
    end
  end
  
  class Clipboard
    def system
      @system ||= java.awt.Toolkit.default_toolkit.system_clipboard
    end
    
    def flavours
      system.available_data_flavors.to_a
    end
    
    def text?
      mime_types.include?( 'text/plain' )
    end
    
    def html?
      mime_types.include?( 'text/html' )
    end
    
    def mime_types
      flavours.map( &:simple_type ).sort.uniq
    end
    
    def full_mime_types
      flavours.map( &:mime_type )
    end
    
    def contents( mime_type )
      flavor = java.awt.datatransfer.DataFlavor.new( "#{mime_type}; class=java.lang.String; charset=UTF-8" )
      system.getData( flavor )
    end
    
    def data( full_mime_type )
      flavor = java.awt.datatransfer.DataFlavor.new( full_mime_type )
      system.getData( flavor )
    end
    
    def stream( mime_type )
      flavor = java.awt.datatransfer.DataFlavor.new( "#{mime_type}; class=java.io.InputStream; charset=UTF-8" )
      Stream.new( system.getData( flavor ) )
    end
    
    def []( mime_type )
      contents( mime_type ).unpack('U*').inject([]) do |collect,byte|
        # ignore BOM
        collect << byte unless byte == 65533
        collect
      end.pack( "U*" )
    end
  end

end
