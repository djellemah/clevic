#! /usr/bin/jruby

require 'rubygems'
require 'sequel'

require 'clevic/swing'
require 'clevic/extensions.rb'

require File.dirname( __FILE__ ) + '/../models/times_psql_models.rb'

class ShowDelegates
  def initialize
    @controls = {}
  end
  
  def frame
    @frame ||= javax.swing.JFrame.new.tap do |frame|
      frame.layout = javax.swing.BoxLayout.new( frame.content_pane, javax.swing.BoxLayout::PAGE_AXIS )
    end
  end
  
  def view
    @view ||= Clevic::View[:invoice].new
  end
  
  attr_reader :controls
  
  def build( entity = entity )
    # add controls
    view.fields.map do |name,field|
      component = 
      if field.delegate
        field.delegate.with do |d|
          d.entity = entity
          d.init_component
          d.editor
        end
      else
        javax.swing.JLabel.new( "no delegate #{name.to_s}" )
      end
      @controls[name] = component
      component
    end
  end
  
  def model
    view.entity_class
  end
  
  def entity
    @entity ||= model[ (model.count * rand ).to_i ] || entity
  end
  
  def show
    # general setup
    frame.default_close_operation = javax.swing.JFrame::HIDE_ON_CLOSE
    frame.pack
    frame.visible = true 
  end
end

def run
  ShowDelegates.new.tap do |sd|
    sd.build.each do |control|
      sd.frame.content_pane.add( control )
    end
    sd.show
  end
end

run unless $0 == 'jirb'
