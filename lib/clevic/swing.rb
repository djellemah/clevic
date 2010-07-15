require 'pathname'

( Pathname.new( __FILE__ ).parent + 'swing' ).children.grep( /.rb$/ ).each do |child|
  require child.to_s
end
