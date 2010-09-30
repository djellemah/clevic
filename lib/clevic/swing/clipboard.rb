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

  # Wrapper for java.io.InputStream to make it nicer for Ruby
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
    
    def text; contents('text/plain'); end
    
    def text=( value )
      transferable = java.awt.datatransfer.StringSelection.new( value )
      system.setContents( transferable, transferable )
    end
    
    def html?
      mime_types.include?( 'text/html' )
    end
    
    def html; contents('text/html'); end
    
    def mime_types
      flavours.map( &:simple_type ).sort.uniq
    end
    
    def full_mime_types
      flavours.map( &:mime_type )
    end
    
    # matcher is either a string or a regex, ie something
    # that can be passed to Array#grep
    def has?( matcher )
      !full_mime_types.grep( matcher ).empty?
    end
    
    # try a bunch of encodings for the given mime_type, and give
    # back a String containing the result
    def contents( mime_type )
      case
        # try UTF-8 first because it seems more robust
        when has?( %r{#{mime_type}.*String.*utf-8}i )
          data "#{mime_type}; class=java.lang.String; charset=UTF-8"
        
        # now string Unicode, just in case
        when has?( %r{#{mime_type}.*String.*unicode}i )
          data "#{mime_type}; class=java.lang.String; charset=unicode"
          
        # This is to handle clevic-clevic pastes
        when has?( %r{#{mime_type}.*Stream.*unicode}i )
          stream( "#{mime_type}; class=java.io.InputStream; charset=unicode" ).read
        
        else
          raise "Don't know how to get #{mime_type}"
      end
    end
    
    def data( full_mime_type )
      flavor = java.awt.datatransfer.DataFlavor.new( full_mime_type )
      system.getData( flavor )
    end
    
    def stream( full_mime_type )
      Stream.new( data( full_mime_type ) )
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
