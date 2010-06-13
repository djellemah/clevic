require 'sequel'

require 'faker'
require 'generator'

# Doesn't seem to be a good place to put this
$db = Sequel.sqlite
Sequel.extension :migration

class Flight < Sequel::Model
  one_to_many :passengers
end

class Passenger < Sequel::Model
  many_to_one :flight
end

class CreateFlights < Sequel::Migration
  def up
    # this executes in the context of a Sequel::Database
    create_table! :flights do
      primary_key :id
      String :number
      String :airline
      String :destination
    end
    
    self[:flights].tap do |fs|
      fs.insert :number => 'EK211'
      fs.insert :number => 'EK761'
      fs.insert :number => 'BA264'
    end
  end
  
  def down
    #~ drop_table :flights
    self[:flights].delete
  end
end

class CreatePassengers < Sequel::Migration
  def up
    create_table! :passengers do
      primary_key :id
      String :name
      String :nationality
      Integer :flight_id
      Integer :row
      String :seat
    end
  end
  
  def down
    #~ drop_table :passengers
    self[:passengers].delete
  end
end

class PopulateCachePassengers < Sequel::Migration
  def up
    flight_ids = @db[:flights].select(:id )
    @db[:passengers].tap do |ps|
      ps.insert :name => 'John Anderson', :flight_id => flight_ids.filter( :number => 'EK211' ).single_value, :row => 36, :seat => 'A', :nationality => 'UAE'
      ps.insert :name => 'Genie', :flight_id => flight_ids.filter( :number => 'CA001').single_value, :row => 1, :seat => 'A', :nationality => 'Canada'
      ps.insert :name => 'Aladdin', :flight_id => flight_ids.filter( :number => 'CA001').single_value, :row => 2, :seat => 'A', :nationality => 'Canada'
    end
  end
  
  def down
    @db[:passengers].delete
  end
end

class CreateFakePassengers < Sequel::Migration
  MAX_PASSENGERS = 100
  NATIONALITIES = %w{Canada USA Britain UAE}
  
  def up
    @db[:passengers].tap do |ps|
      1.upto( MAX_PASSENGERS ) do |i|
        flight_id = @db[:flights].filter.limit( 1, i%4 ).select( :id ).single_value
        ps.insert :name => Faker::Name.name, :flight_id => flight_id, :nationality => NATIONALITIES[i%4], :row => i, :seat => %w{A B C D}[i % 4]
      end
    end
  end
  
  def down
    @db[:passengers].delete
  end
end

def all
  Sequel::Migration.descendants.each do |mgr|
    mgr.new( $db ).up
  end
end
