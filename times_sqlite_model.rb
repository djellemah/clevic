require 'clevic.rb'

# db connection options
Clevic::DbOptions.connect( $options ) do
  database :times
  adapter :sqlite3
end

# model definitions
class Entry < ActiveRecord::Base
  include ActiveRecord::Dirty
  belongs_to :invoice
  belongs_to :activity
  belongs_to :project
  
  # define how fields are displayed
  def self.ui( parent )
    Clevic::TableView.new( self, parent ).create_model do
      plain       :date, :sample => '28-Dec-08'
      relational  :project, :display => 'project', :conditions => "active = true", :order => 'lower(project)'
      relational  :invoice, :display => 'invoice_number', :conditions => "status = 'not sent'", :order => 'invoice_number'
      plain       :start
      plain       :end
      plain       :description, :sample => 'This is a long string designed to hold lots of data and description'
      relational  :activity, :display => 'activity', :order => 'lower(activity)', :sample => 'Troubleshooting', :conditions => 'active = #{connection.quoted_true}'
      distinct    :module, :tooltip => 'Module or sub-project'
      plain       :charge, :tooltip => 'Is this time billable?'
      distinct    :person, :tooltip => 'The person who did the work'
      
      records     :order => 'date, start, id'
    end
  end

  # called when a key is pressed in this model's table view
  def self.key_press_event( event, current_index, view )
    case
      # copy almost all of the previous line
      when event.ctrl? && event.quote_dbl?
        if current_index.row > 1
          # fetch previous item
          model = current_index.model
          previous_item = model.collection[current_index.row - 1]
          
          # copy the relevant fields
          current_index.entity.start = previous_item.end
          [:date, :project, :invoice, :activity, :module, :charge, :person].each do |attr|
            current_index.entity.send( "#{attr.to_s}=", previous_item.send( attr ) )
          end
          
          # tell view to update
          top_left_index = model.create_index( current_index.row, 0 )
          bottom_right_index = model.create_index( current_index.row, current_index.column + view.builder.fields.size )
          view.dataChanged( top_left_index, bottom_right_index )
          
          # move to end time field
          view.override_next_index( model.create_index( current_index.row, view.builder.index( :end ) ) )
        end
        # don't let anybody else handle the keypress
        return true
      
      when event.ctrl? && event.i?
        invoice_from_project( current_index, view )
        # don't let anybody else handle the keypress
        return true
    end
  end
  
  # called when data is changed in this model's table view
  def self.data_changed( top_left, bottom_right, view )
    invoice_from_project( top_left, view ) if ( top_left == bottom_right )
  end
  
  def self.invoice_from_project( current_index, view )
    # auto-complete invoice number field from project
    current_field = current_index.attribute
    if current_field == :project && current_index.entity.project != nil
      # most recent entry, ordered in reverse
      invoice = current_index.entity.project.latest_invoice
      
      unless invoice.nil?
        # make a reference to the invoice
        current_index.entity.invoice = invoice
        
        # update view from top_left to bottom_right
        model = current_index.model
        changed_index = model.create_index( current_index.row, view.builder.index( :invoice ) )
        view.dataChanged( changed_index, changed_index )
        
        # move edit cursor to start time field
        view.override_next_index( model.create_index( current_index.row, view.builder.index( :start ) ) )
      end
    end
  end
end

class Project < ActiveRecord::Base
  include ActiveRecord::Dirty
  has_many :entries

  def self.ui( parent )
    Clevic::TableView.new( Project, parent ).create_model do
      plain     :project
      plain     :description
      distinct  :client
      plain     :rate
      plain     :active
      
      records   :order => 'project'
    end
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
  include ActiveRecord::Dirty
  has_many :entries

  # define how fields are displayed
  def self.ui( parent )
    Clevic::TableView.new( Activity, parent ).create_model do
      plain :activity
      plain :active
      
      records :order => 'activity'
    end
  end
end

class Invoice < ActiveRecord::Base
  include ActiveRecord::Dirty
  has_many :entries

  # define how fields are displayed
  def self.ui( parent )
    Clevic::TableView.new( Invoice, parent ).create_model do
      plain :date
      distinct :client, :frequency => true
      plain :invoice_number
      restricted :status, :set => ['not sent', 'sent', 'paid', 'debt', 'writeoff', 'internal']
      restricted :billing, :set => %w{Hours Quote Internal}
      plain :quote_date
      plain :quote_amount
      plain :description
      
      records :order => 'invoice_number'
    end
  end
end

# tab widget order
$options[:models] = [ Entry, Invoice, Project, Activity ]
