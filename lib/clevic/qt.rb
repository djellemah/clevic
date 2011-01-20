=begin
  Require this file to do Clevic in Qt
=end

require 'pathname'

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

module Clevic

def self.tahoma
  if @font.nil?
    @font = 
    begin
      found = java.awt.GraphicsEnvironment.local_graphics_environment.all_fonts.select {|f| f.font_name == "Tahoma"}.first
      found.deriveFont( 13.0 )
      java.awt.Font.new( 'DialogInput', java.awt.Font::PLAIN, 13 )
  rescue
      java.awt.Font.new( 'DialogInput', java.awt.Font::PLAIN, 13 )
    end
  end
  @font
end

end
