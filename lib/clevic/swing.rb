=begin
  Require this file to do Clevic in Swing with JRuby
=end

require 'pathname'

# This seems to be required for jruby-1.5.x (at least for 1.5.2)
require 'java'

# require these first, so TableModel and TableView get the correct ancestors
require 'clevic/swing/table_model.rb'
require 'clevic/swing/table_view.rb'
( Pathname.new( __FILE__ ).parent + 'swing' ).children.grep( /.rb$/ ).each do |child|
  require child.to_s
end

# now require the generic parts
require 'clevic/table_model'
require 'clevic/table_view'
require 'clevic.rb'

module Clevic

def self.tahoma
  if @font.nil?
    found =
    begin
      java.awt.GraphicsEnvironment.local_graphics_environment.all_fonts.select {|f| f.font_name == "Tahoma"}.first
    rescue
      puts "oops. Using SansSerif"
      java.awt.GraphicsEnvironment.local_graphics_environment.all_fonts.select {|f| f.font_name == "SansSerif"}.first
    end
    @font = found.deriveFont( 13.0 )
  end
  @font
end

end
