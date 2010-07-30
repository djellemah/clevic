#! /usr/bin/jruby

require 'rubygems'
require 'sequel'

require 'clevic/swing'

require File.dirname( __FILE__ ) + '/../models/times_psql_models.rb'

class ShowDelegates
  def frame
    @frame ||= javax.swing.JFrame.new.tap do |frame|
      frame.layout = javax.swing.BoxLayout.new( frame.content_pane, javax.swing.BoxLayout::PAGE_AXIS )
    end
  end
  
  def view
    @view ||= Clevic::View.order.first.new
  end

  def build( entity = entry )
    # add controls
    controls = view.fields.map do |name,field|
      puts "name: #{name.inspect}"
      component = 
      if field.delegate
        field.delegate.component( entity )
      else
        javax.swing.JLabel.new( name.to_s )
      end
    end
  end
  
  def entry
    Entry[ (Entry.count * rand ).to_i ] || entry
  end
  
  def show
    # general setup
    frame.default_close_operation = javax.swing.JFrame::EXIT_ON_CLOSE
    frame.pack
    frame.visible = true 
  end
end

ShowDelegates.new.tap do |sd|
  sd.build.each do |control|
    sd.frame.content_pane.add( control )
  end
  sd.show
end
