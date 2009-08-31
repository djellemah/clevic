require 'clevic.rb'

# model definitions
class Entry < ActiveRecord::Base
  belongs_to :invoice
  belongs_to :activity
  belongs_to :project
  
  include Clevic::Record
  def time_color
    return if self.end.nil? || start.nil?
    'darkviolet' if self.end - start > 8.hours
  end
  
  def time_tooltip
    return if self.end.nil? || start.nil?
    'Time interval greater than 8 hours' if self.end - start > 8.hours
  end
  
  define_ui do
    plain       :date, :sample => '28-Dec-08'
    relational  :project do |field|
      field.display = 'project'
      field.conditions = 'active = true'
      field.order = 'lower(project)'
      field.notify_data_changed = lambda do |entity_view, table_view, model_index|
        if model_index.entity.invoice.nil?
          entity_view.invoice_from_project( table_view, model_index ) do
            table_view.override_next_index model_index.choppy( :column => :start )
          end
        end
      end
    end
    relational  :invoice, :display => 'invoice_number', :conditions => "status = 'not sent'", :order => 'invoice_number'
    plain       :start, :foreground => :time_color, :tooltip => :time_tooltip
    plain       :end, :foreground => lambda{|x| x.time_color}, :tooltip => :time_tooltip
    text        :description, :sample => 'This is a long string designed to hold lots of data and description'
    
    relational :activity do
      display    'activity'
      order      'lower(activity)'
      sample     'Troubleshooting'
      conditions 'active = true'
    end
    
    distinct    :module, :tooltip => 'Module or sub-project'
    plain       :charge, :tooltip => 'Is this time billable?'
    distinct    :person, :default => 'John', :tooltip => 'The person who did the work'
    
    records     :order => 'date, start, id'
  end

  def self.define_actions( view, action_builder )
    action_builder.action :smart_copy, 'Smart Copy', :shortcut => 'Ctrl+"' do
      smart_copy( view )
    end
    
    action_builder.action :invoice_from_project, 'Invoice from Project', :shortcut => 'Ctrl+Shift+I' do
      invoice_from_project( view, view.current_index )
      # save this before selection model is cleared
      current_index = view.current_index
      view.selection_model.clear
      view.current_index = current_index.choppy( :column => :start )
    end
  end
  
  # do a smart copy from the previous line
  def self.smart_copy( view )
    view.sanity_check_read_only
    view.sanity_check_ditto
    
    # need a reference to current_index here, because selection_model.clear will
    # invalidate view.current_index. And anyway, its shorter and easier to read.
    current_index = view.current_index
    if current_index.row >= 1
      # fetch previous item
      previous_item = view.model.collection[current_index.row - 1]
      
      # copy the relevant fields
      current_index.entity.date = previous_item.date if current_index.entity.date.blank?
      # depends on previous line
      current_index.entity.start = previous_item.end if current_index.entity.date == previous_item.date
      
      # copy rest of fields
      [:project, :invoice, :activity, :module, :charge, :person].each do |attr|
        current_index.entity.send( "#{attr.to_s}=", previous_item.send( attr ) )
      end
      
      # tell view to update
      view.model.data_changed do |change|
        change.top_left = current_index.choppy( :column => 0 )
        change.bottom_right = current_index.choppy( :column => view.model.fields.size - 1 )
      end
      
      # move to the first empty time field
      next_field =
      if current_index.entity.start.blank?
        :start
      else
        :end
      end
      
      # next cursor location
      view.selection_model.clear
      view.current_index = current_index.choppy( :column => next_field )
    end
  end

  # auto-complete invoice number field from project
  # block will be executed if an invoice was assigned
  def self.invoice_from_project( table_view, current_index, &block )
    if current_index.entity.project != nil && current_index.entity.invoice.nil?
      # most recent entry, ordered in reverse
      invoice = current_index.entity.project.latest_invoice
      unless invoice.nil?
        # make a reference to the invoice
        current_index.entity.invoice = invoice
        
        # update view from top_left to bottom_right
        table_view.model.data_changed( current_index.choppy( :column => :invoice ) )
        
        unless block.nil?
          if block.arity == 1
            block.call( invoice )
          else
            block.call
          end
        end
      end
    end
  end
end

class Invoice < ActiveRecord::Base
  include Clevic::Record
  has_many :entries

  define_ui do
    plain :date
    distinct :client
    plain :invoice_number
    restricted :status, :set => ['not sent', 'sent', 'paid', 'debt', 'writeoff', 'internal']
    restricted :billing, :set => %w{Hours Quote Internal}
    plain :quote_date, :format => '%d-%b-%y', :edit_format => '%d-%b-%Y', :tooltip => 'the date and time when the quote was supplied', :default => lambda{|x| DateTime.now}
    plain :quote_amount
    plain :description
    
    records :order => 'invoice_number'
  end
end

class Project < ActiveRecord::Base
  include Clevic::Record
  has_many :entries

  define_ui do
    plain     :project
    plain     :description
    distinct  :client
    plain     :rate
    plain     :active
    
    records   :order => 'project'
  end
  
  # Return the latest invoice for this project
  # Not part of the UI.
  def latest_invoice
    Invoice.find(
      :first,
      :conditions => ["client = ? and status = 'not sent'", self.client],
      :order => 'invoice_number desc'
    )
  end

end

class Activity < ActiveRecord::Base
  include Clevic::Record
  has_many :entries

  # define how fields are displayed
  define_ui do
    plain :activity
    plain :active
    
    records :order => 'activity'
  end
end
