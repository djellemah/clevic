#! /usr/bin/ruby

require 'Qt4'
require 'active_table_model.rb'
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

model = ActiveTableModel.new(
  entries,
  %w{date invoice.invoice_number project.project start end description module charge person}
)

table = EntryTableView.new
table.model = model
table.sorting_enabled = true
table.resize_columns_to_contents

table.relational_delegate( :invoice, :conditions => "status = 'not sent'", :order => 'invoice_number' )
table.relational_delegate( :project, :conditions => "active = true", :order => 'lower(project)' )

#~ table.showMaximized
table.show

begin
  app.exec
rescue Exception => e
  puts e.backtrace.join( "\n" )
  puts e.message
end
