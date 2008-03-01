require 'active_record'
require 'active_record/dirty.rb'

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
      t.relational  :invoice, 'invoice_number', :sample => 'WWW000', :conditions => "status = 'not sent'", :order => 'invoice_number'
      t.relational  :project, 'project', :sample => 'Some Project', :conditions => 'active = true', :order => 'lower(project)'
      t.plain       :start, :sample => '00:00'
      t.plain       :end, :sample => '00:00'
      t.plain       :description, :sample => 'This is a long string designed to hold lots of data and description'
      t.relational  :activity, 'activity', :order => 'lower(activity)', :sample => 'Troubleshooting'
      t.distinct    :module, :sample => 'Doing Stuff'
      t.plain       :charge, :sample => 'Charge'
      t.distinct    :person, :sample => 'Leilani'
      
      t.collection = self.find( :all, :order => 'date, start, id' )
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
      
      t.collection = Project.find( :all, :order => 'id' )
    end
  end
end

class Activity < ActiveRecord::Base
  include ActiveRecord::Dirty
  has_many :entries

  def self.ui( parent )
    EntryTableView.new( Activity, parent ).create_model do |t|
      t.plain :activity
      
      t.collection = Activity.find( :all, :order => 'id' )
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
