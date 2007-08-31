#! /usr/bin/ruby

require 'Qt4'
require 'entry_table_model.rb'
require 'models.rb'
require 'delegates.rb'
require 'entry_table_view.rb'

# turn off "Object#type deprecated" messages
$VERBOSE=nil

app = Qt::Application.new(ARGV)

# last 100 entries in table
entries = Entry.find(
  :all,
  :order => 'id desc',
  :limit => 100
)
entries.reverse!

model = EntryTableModel.new(
  entries,
  %w{date invoice.invoice_number project.project start end description activity.activity module charge person}
)

table = EntryTableView.new
table.model = model
table.sorting_enabled = true
table.resize_columns_to_contents

# fetch list from related tables
table.relational_delegate( :invoice, :conditions => "status = 'not sent'", :order => 'invoice_number' )
table.relational_delegate( :project, :conditions => "active = true", :order => 'lower(project)' )
table.relational_delegate( :activity, :order => 'lower(activity)' )

# fetch list from column
table.delegate( :person, DistinctDelegate )
table.delegate( :module, DistinctDelegate )

#~ table.showMaximized
table.show

begin
  app.exec
rescue Exception => e
  puts e.backtrace.join( "\n" )
  puts e.message
end
