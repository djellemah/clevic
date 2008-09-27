require 'clevic/db_options.rb'
require 'clevic/field.rb'
require 'clevic/order_attribute.rb'
require 'activerecord'
require 'sqlite3'
require 'faker'
require 'generator'

MAX_PASSENGERS = 100

class OneBase
  attr_reader :db_name, :adapter
  
  def initialize
    @db_name = 'test_cache_table.sqlite3'

    if File.exists? @db_name
      p 'remove old db'
      File.unlink @db_name
    end
    
    @adapter = :sqlite3
    @db = SQLite3::Database.new( @db_name )
    @db_options = Clevic::DbOptions.connect do |dbo|
      dbo.database @db_name
      dbo.adapter @adapter
    end
  end

  def feenesh
    File.unlink @db_name
  end
end

# must be after DB connection
class Passenger < ActiveRecord::Base
end

class CreateFakePassengers < ActiveRecord::Migration
  def self.flights
    %w{EK211 EK088 EK761 BA264}
  end
  
  def self.up
    create_table :passengers do |t|
      t.string :name
      t.string :flight
      t.integer :row
      t.string :seat
    end
    Passenger.reset_column_information
    
    1.upto( MAX_PASSENGERS ) do |i|
      Passenger.create :name => Faker::Name.name, :flight => flights[i % flights.size], :row => i, :seat => %w{A B C D}[i % 4]
    end
  end
  
  def self.down
    drop_table :passengers
  end
end
