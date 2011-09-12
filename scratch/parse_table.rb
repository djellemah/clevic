require 'hpricot'

def parse_table
  ary = ( doc / :tr ).map do |row|
    ( row / :td ).map do |cell|
      # trim leading and trailing \r\n\t

      # check for br
      unless cell.search( '//br' ).empty?
        # treat br as separate lines
        cell.search('//text()').map( &:to_s ).join("\n")
      else
        # otherwise just join text elements
        cell.search( '//text()' ).join('')
      end.gsub( /^[\r\n\t]*/, '').gsub( /[\r\n\t]*$/, '')
    end
  end
end

def clipboard
  require 'clevic/swing/clipboard'
  @clipboard ||= Clevic::Clipboard.new
end

def write( name = '/tmp/postible.html' )
  @html = nil
  @doc = nil
  File.open( name, 'w' ){|f| f.write html}
end

def read( name = '/tmp/postible.html' )
  @html = File.read name
end

def html
  @html ||= clipboard['text/html']
end

def doc
  @doc ||= Hpricot.parse( html )
end

read; doc
