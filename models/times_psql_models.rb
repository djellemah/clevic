$options ||= {}

require 'clevic.rb'
host = ENV['PGHOST'] || 'localhost'
constring = "jdbc:postgresql://#{host}/times_test?user=#{$options[:username] || 'times'}&password=general"
puts "constring: #{constring.inspect}"
Sequel.connect( constring )

require 'times_models.rb'
