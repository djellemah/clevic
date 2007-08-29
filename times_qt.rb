#! /usr/bin/ruby

require 'Qt4'
require 'pp'

puts "drivers: "
pp Qt::SqlDatabase.drivers
db = Qt::SqlDatabase::addDatabase( "QPSQL" );
pp db.last_error.database_text
db.setHostName("localhost");
db.setDatabaseName("times");
db.setUserName("panic");
db.setPassword("");
if db.open()
  puts "db open"
else
  puts "db did not open"
end
