$options ||= {}

require 'clevic.rb'
host = ENV['PGHOST'] || 'localhost'
ENV['CLASSPATH'] << ":/home/panic/projects/distlist/jars/postgresql-8.4-702.jdbc3.jar"
constring = "jdbc:postgresql://#{host}/times_test?user=#{$options[:username] || 'times'}&password=general"
puts "constring: #{constring.inspect}"
Sequel.connect( constring )

require 'times_models.rb'
