=begin
  Require this file to do Clevic in Qt
=end

require 'pathname'

require 'clevic/framework'

# require these first, so TableModel and TableView get the correct ancestors
require 'clevic/qt/table_model.rb'
require 'clevic/qt/table_view.rb'

# all other files in the qt subdirectory
( Pathname.new( __FILE__ ).parent + 'qt' ).children.grep( /.rb$/ ).each do |child|
  require child.to_s
end

# now require the generic parts
require 'clevic/table_model'
require 'clevic/table_view'
require 'clevic.rb'
