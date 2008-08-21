require 'clevic.rb'

# db connection options
db = Clevic::DbOptions.connect( $options ) do
  # use a different db for testing, so real data doesn't get broken.
  database( debug? ? :times_test : :times )
  adapter :postgresql
  username 'times'
end

# model definitions
class Entry < Clevic::Record
  belongs_to :invoice
  belongs_to :activity
  belongs_to :project
  
  define_ui do
    plain       :date, :sample => '28-Dec-08'
    relational  :project, :display => 'project', :conditions => 'active = true', :order => 'lower(project)'
    relational  :invoice, :display => 'invoice_number', :conditions => "status = 'not sent'", :order => 'invoice_number'
    plain       :start
    plain       :end
    plain       :description, :sample => 'This is a long string designed to hold lots of data and description'
    relational  :activity, :display => 'activity', :order => 'lower(activity)', :sample => 'Troubleshooting', :conditions => 'active = true'
    
    # TODO specify complex fields like this:
    #~ relational :activity do
      #~ display 'activity'
      #~ order 'lower(activity)'
      #~ sample 'Troubleshooting'
      #~ conditions 'active = true'
    #~ end
    
    distinct    :module, :tooltip => 'Module or sub-project'
    plain       :charge, :tooltip => 'Is this time billable?'
    distinct    :person, :tooltip => 'The person who did the work'
    
    records     :order => 'date, start, id'
  end

  def self.actions( view, action_builder )
    action_builder.action :smart_copy, 'Smart Copy', :shortcut => 'Ctrl+"' do
      smart_copy( view )
    end
    
    action_builder.action :invoice_from_project, 'Invoice from Project', :shortcut => 'Ctrl+Shift+I' do
      invoice_from_project( view.current_index, view )
    end
  end
  
  # do a smart copy from the previous line
  def self.smart_copy( view )
    view.sanity_check_read_only
    view.sanity_check_ditto
    
    if view.current_index.row > 1
      # fetch previous item
      model = view.model
      previous_item = model.collection[view.current_index.row - 1]
      
      # copy the relevant fields
      view.current_index.entity.start = previous_item.end
      [:date, :project, :invoice, :activity, :module, :charge, :person].each do |attr|
        view.current_index.entity.send( "#{attr.to_s}=", previous_item.send( attr ) )
      end
      
      # tell view to update
      top_left_index = model.create_index( view.current_index.row, 0 )
      bottom_right_index = model.create_index( view.current_index.row, view.current_index.column + view.builder.fields.size )
      view.dataChanged( top_left_index, bottom_right_index )
      
      # move to end time field
      view.override_next_index( model.create_index( view.current_index.row, view.builder.index( :end ) ) )
    end
  end

  # called when data is changed in this model's table view
  def self.data_changed( top_left, bottom_right, view )
    invoice_from_project( top_left, view ) if ( top_left == bottom_right )
  end
  
  # auto-complete invoice number field from project
  def self.invoice_from_project( current_index, view )
    current_field = current_index.attribute
    if [:project,:invoice].include?( current_field ) && current_index.entity.project != nil
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

class Invoice < Clevic::Record
  has_many :entries

  define_ui do
    plain :date
    distinct :client
    plain :invoice_number
    restricted :status, :set => ['not sent', 'sent', 'paid', 'debt', 'writeoff', 'internal']
    restricted :billing, :set => %w{Hours Quote Internal}
    plain :quote_date
    plain :quote_amount
    plain :description
    
    records :order => 'invoice_number'
  end
end

class Project < Clevic::Record
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

class Activity < Clevic::Record
  has_many :entries

  # define how fields are displayed
  define_ui do
    plain :activity
    plain :active
    
    records :order => 'activity'
  end
end
