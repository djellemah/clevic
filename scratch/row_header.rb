#! /usr/bin/jruby

require 'rubygems'
require 'sequel'
require 'andand'
require 'clevic/swing'
require 'clevic/swing/row_header.rb'

require File.dirname( __FILE__ ) + '/../models/times_psql_models.rb'

def run
  @frame = javax.swing.JFrame.new.tap do |frame|
    # the table
    view = Clevic::View.order.first.new
    @table_view = Clevic::TableView.new( view )
    
    # display
    frame.content_pane.add( @table_view )
    frame.default_close_operation = javax.swing.JFrame::DISPOSE_ON_CLOSE
    frame.pack
    frame.visible = true 
  end
end

def reload
  @frame.andand.dispose
  load __FILE__
  load 'clevic/swing/row_header.rb'
  load 'clevic/swing/table_view.rb'
  load 'clevic/swing/table_view_focus.rb'
end

run unless $0 == 'jirb'
