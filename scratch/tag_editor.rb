#! /usr/bin/jruby

require 'rubygems'
require 'sequel'
require 'andand'
require 'clevic/swing'
require 'clevic/swing/tag_delegate.rb'

require File.dirname( __FILE__ ) + '/../models/contacts.rb'

def run
  @frame = javax.swing.JFrame.new.tap do |frame|
    # the view
    @view = Clevic::View.order.first.new
    
    # the editor
    @tag_editor = Clevic::TagEditor.new( @view.fields )
    
    # display
    frame.content_pane.add( @tag_editor )
    frame.default_close_operation = javax.swing.JFrame::DISPOSE_ON_CLOSE
    frame.pack
    frame.visible = true 
  end
end

def reload
  @frame.andand.dispose
  load __FILE__
  load 'clevic/swing/tag_delegate.rb'
  load 'clevic/swing/delegate.rb'
  load 'clevic/model_builder.rb'
end

run unless $0 == 'jirb'
