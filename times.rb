#! /usr/bin/ruby

require 'Qt4'
require 'active_table_model.rb'
require 'models.rb'
require 'relational_delegate.rb'
require 'entry_table_view.rb'

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

table.relational_delegate( 'invoice', :conditions => "status = 'not sent'", :order => 'invoice_number' )
table.relational_delegate( 'project', :conditions => "active = true", :order => 'lower(project)' )
table.delegate( :charge, Qt::CheckBox )

#~ table.showMaximized
table.show

begin
  app.exec
rescue Exception => e
  puts e.backtrace.join( "\n" )
  puts e.message
end
