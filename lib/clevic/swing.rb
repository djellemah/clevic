=begin
  Require this file to do Clevic in Swing with JRuby
=end

require 'pathname'

# require these first, so TableModel and TableView get the correct ancestors
( Pathname.new( __FILE__ ).parent + 'swing' ).children.grep( /.rb$/ ).each do |child|
  require child.to_s
end

# no require the generic parts
require 'clevic/table_model'
require 'clevic/table_view'
