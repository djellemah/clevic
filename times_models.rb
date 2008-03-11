require 'rubygems'
require 'active_record'
require 'active_record/dirty.rb'

$options ||= {}
$options[:database] ||= 'times'

# model definitions
class Entry < ActiveRecord::Base
  include ActiveRecord::Dirty
  belongs_to :invoice
  belongs_to :activity
  belongs_to :project
  
  def self.ui( parent )
    EntryTableView.new( self, parent ).create_model do |t|
      t.plain       :date, :sample => '28-Dec-08'
      t.relational  :project, 'project', :sample => 'Project', :conditions => 'active = true', :order => 'lower(project)'
      t.relational  :invoice, 'invoice_number', :sample => 'WWW000', :conditions => "status = 'not sent'", :order => 'invoice_number'
      t.plain       :start, :sample => '00:00'
      t.plain       :end, :sample => '00:00'
      t.plain       :description, :sample => 'This is a long string designed to hold lots of data and description'
      t.relational  :activity, 'activity', :order => 'lower(activity)', :sample => 'Troubleshooting', :conditions => 'active = true'
      t.distinct    :module, :sample => 'Doing Stuff'
      t.plain       :charge, :sample => 'Charge'
      t.distinct    :person, :sample => 'Leilani'
      
      t.collection = self.find( :all, :order => 'date, start, id' )
    end
  end

  def self.key_press_event( event, current_index, view )
    case
      # copy almost all of the previous line
      when event.ctrl? && event.quote_dbl?
        if current_index.row > 1
          # fetch the two row models
          model = current_index.model
          previous_item = model.collection[current_index.row - 1]
          current_item = model.collection[current_index.row]
          
          # copy the relevant fields
          current_item.start = previous_item.end
          [:date, :project, :invoice, :activity, :module, :charge, :person].each do |attr|
            current_item.send( "#{attr.to_s}=", previous_item.send( attr ) )
          end
          
          # tell view to update
          top_left_index = model.create_index( current_index.row, 0 )
          bottom_right_index = model.create_index( current_index.row, current_index.column + view.builder.fields.size )
          view.dataChanged( top_left_index, bottom_right_index )
          
          # move to end time field
          end_index = model.create_index( current_index.row, view.builder.index( :end ) )
          view.set_current_index( end_index )
        end
        # don't let anybody else handle the keypress
        return true
      
      when event.ctrl? && event.i?
        invoice_from_project( current_index, view, nil )
        # don't let anybody else handle the keypress
        return true
    end
  end
  
  def self.close_editor( current_index, view, end_edit_hint )
    invoice_from_project( current_index, view, end_edit_hint )
  end
  
  def self.invoice_from_project( current_index, view, end_edit_hint )
    # auto-complete invoice number field from project
    current_field = current_index.attribute
    if current_field == :project && current_index.entity.project != nil
      # most recent entry, ordered in reverse
      invoice = Invoice.find(
        :first,
        :conditions => ["client = ? and status = 'not sent'", current_index.entity.project.client],
        :order => 'invoice_number desc'
      )
      
      if invoice != nil
        # make a reference to the invoice
        current_index.entity.invoice = invoice
        
        # update view from top_left to bottom_right
        model = current_index.model
        changed_index = model.create_index( current_index.row, view.builder.index( :invoice ) )
        view.dataChanged( changed_index, changed_index )
        
        # move edit cursor to start
        view.set_current_index( model.create_index( current_index.row, view.builder.index( :start ) ) )
      end
    end
  end
end

class Project < ActiveRecord::Base
  include ActiveRecord::Dirty
  has_many :entries

  def self.ui( parent )
    EntryTableView.new( Project, parent ).create_model do |t|
      t.plain :project
      t.plain :description
      t.plain :client
      t.plain :rate
      t.plain :active
      
      t.collection = Project.find( :all, :order => 'project' )
    end
  end
end

class Activity < ActiveRecord::Base
  include ActiveRecord::Dirty
  has_many :entries

  def self.ui( parent )
    EntryTableView.new( Activity, parent ).create_model do |t|
      t.plain :activity
      t.plain :active
      
      t.collection = Activity.find( :all, :order => 'activity' )
    end
  end
end

class Invoice < ActiveRecord::Base
  include ActiveRecord::Dirty
  has_many :entries

  def self.ui( parent )
    EntryTableView.new( Invoice, parent ).create_model do |t|
      t.plain :date
      t.plain :client
      t.plain :invoice_number
      t.distinct :status
      t.plain :billing
      t.plain :quote_date
      t.plain :quote_amount
      t.plain :description
      
      t.collection = Invoice.find( :all, :order => 'invoice_number' )
    end
  end
end
