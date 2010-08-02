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

module Clevic

def self.tahoma
  if @font.nil?
    found = java.awt.GraphicsEnvironment.local_graphics_environment.all_fonts.select {|f| f.font_name == "Tahoma"}.first
    @font = found.deriveFont( 13.0 )
  end
  @font
end

end
