require File.dirname(__FILE__) + '/test_helper'
require 'clevic/table_searcher.rb'
require 'activerecord'
require 'sqlite3'
require 'faker'
require 'generator'

class Passenger < ActiveRecord::Base
end

MAX_PASSENGERS = 100

$flights = %w{EK211 EK088 EK761 BA264}

class CreatePassengers < ActiveRecord::Migration
  def self.up
    create_table :passengers do |t|
      t.string :name
      t.string :flight
      t.integer :row
      t.string :seat
    end
    Passenger.reset_column_information
    
    1.upto( MAX_PASSENGERS ) do |i|
      Passenger.create :name => Faker::Name.name, :flight => $flights[i % $flights.size], :row => i, :seat => %w{A B C D}[i % 4]
    end
  end
  
  def self.down
  end
end

class MockSearchCriteria

  def initialize( &block )
    @direction = :forwards
    @from_start = false
    @whole_words = false
    self.instance_eval( &block ) if block_given?
  end
  
  attr_accessor :direction, :search_text
  attr_writer :whole_words, :from_start
  def whole_words?; @whole_words; end
  def from_start?; @from_start; end
end

class OneBase
  def initialize
    @db_name = 'test_cache_table.sqlite3'

    File.unlink @db_name if File.exists? @db_name
    @db = SQLite3::Database.new( @db_name )
    @db_options = Clevic::DbOptions.connect do |dbo|
      dbo.database @db_name
      dbo.adapter :sqlite3
    end
    CreatePassengers.migrate :up
  end

  def feenesh
    File.unlink @db_name
  end
end

OneBase.new

# need to set up a test DB, and test data for this
class TestTableSearch < Test::Unit::TestCase
  
  def setup
    @simple_search_criteria = MockSearchCriteria.new
    @name_field = Clevic::Field.new( :name, Passenger, {} )
    @id_order_attribute = OrderAttribute.new( Passenger, 'id' )
  end
  
  def teardown
  end
  
  def test_count_passengers
    assert_equal MAX_PASSENGERS, Passenger.count, "There should be #{MAX_PASSENGERS} passengers"
  end
  
  def test_init
    # bad initialisations
    assert_raise RuntimeError do
      TableSearcher.new( Passenger, nil, @simple_search_criteria, @name_field )
    end
    
    assert_raise RuntimeError do
      TableSearcher.new( Passenger, [], @simple_search_criteria, @name_field )
    end

    assert_raise RuntimeError do
      TableSearcher.new( Passenger, [], @simple_search_criteria, @name_field )
    end
    
    assert_raise RuntimeError do
      TableSearcher.new( Passenger, [@id_order_attribute], @simple_search_criteria, nil )
    end
    
    # good init
    ts = TableSearcher.new( Passenger, [@id_order_attribute], @simple_search_criteria, @name_field )
    assert_equal :name, ts.field.attribute
  end
  
  # TODO should really do more granular testing, but not until TableSearched is factored better.
  
  def test_search
    # find all passengers on a given flight
    all_passengers = Generator.new( Passenger.find( :all, :conditions => [ 'flight = ?', $flights[0] ], :order => :id ) )
    @simple_search_criteria.search_text = $flights[0]
    @simple_search_criteria.from_start = true
    
    # build the searcher
    flight_field = Clevic::Field.new( :flight, Passenger, {} )
    ts = TableSearcher.new( Passenger, [@id_order_attribute], @simple_search_criteria, flight_field )
    first = ts.search( nil )
    st = ts.instance_eval "@conditions"
    assert_equal all_passengers.next, first, 'first entity found should be the same'
    
    # test the rest
    @simple_search_criteria.from_start = false
    last_entity = first
    while next_entity = ts.search( last_entity )
      assert_equal all_passengers.next, next_entity
      last_entity = next_entity
    end
  end
  
end
