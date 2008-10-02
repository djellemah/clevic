require File.dirname(__FILE__) + '/test_helper.rb'
require 'clevic/table_searcher.rb'

class CreateFakePassengers < ActiveRecord::Migration
  FLIGHTS = %w{EK211 EK088 EK761 BA264}
  MAX_PASSENGERS = 100
  
  def self.up
    1.upto( MAX_PASSENGERS ) do |i|
      Passenger.create :name => Faker::Name.name, :flight => FLIGHTS[i % FLIGHTS.size], :row => i, :seat => %w{A B C D}[i % 4]
    end
  end
  
  def self.down
    Passenger.delete_all
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

class TestTableSearcher < Test::Unit::TestCase
  def self.startup
    CreateFakePassengers.up
  end
  
  def self.shutdown
    CreateFakePassengers.down
  end
  
  def setup
    @simple_search_criteria = MockSearchCriteria.new
    @id_order_attribute = OrderAttribute.new( Passenger, 'id' )

    @name_field = Clevic::Field.new( :name, Passenger, {} )
    @flight_field = Clevic::Field.new( :flight, Passenger, {} )
    @all_passengers = Passenger.find( :all, :conditions => [ 'flight = ?', CreateFakePassengers::FLIGHTS[0] ], :order => :id )
  end

  context 'on initialisation' do
    should "have a matching field attribute on construction" do
      ts = TableSearcher.new( Passenger, [@id_order_attribute], @simple_search_criteria, @name_field )
      assert_equal @name_field.attribute, ts.field.attribute
    end

    should "throw an exception when called with no order attributes" do
      assert_raise( RuntimeError ) do
        TableSearcher.new( Passenger, nil, @simple_search_criteria, @name_field )
      end
    end

    should "throw an exception when called with an empty collection of order attributes" do
      assert_raise( RuntimeError ) do
        TableSearcher.new( Passenger, [], @simple_search_criteria, @name_field )
      end
    end
      
    should "throw an exception when called with no field" do
      assert_raise( RuntimeError ) do
        TableSearcher.new( Passenger, [@id_order_attribute], @simple_search_criteria, nil )
      end
    end
  end
  
  context "searching" do
    setup do
      @simple_search_criteria.search_text = CreateFakePassengers::FLIGHTS[0]
      @passenger_generator = Generator.new( @all_passengers )
    end
    
    should "have #{CreateFakePassengers::MAX_PASSENGERS} passengers" do
      assert_equal CreateFakePassengers::MAX_PASSENGERS, Passenger.count
    end

    should_eventually "do more granular testing"
    
    should "find the first record" do
      @simple_search_criteria.from_start = true
      table_searcher = TableSearcher.new( Passenger, [@id_order_attribute], @simple_search_criteria, @flight_field )
      assert_equal @all_passengers.first, table_searcher.search( nil )
    end
    
    should "find next records" do
      @simple_search_criteria.from_start = false
      table_searcher = TableSearcher.new( Passenger, [@id_order_attribute], @simple_search_criteria, @flight_field )
      
      # fetch records one by one, starting from the one after the first one, and compare them
      while next_entity = table_searcher.search( @passenger_generator.next )
        passenger = @passenger_generator.next
        
        assert_equal next_entity, passenger
        assert_not_equal @all_passengers.first, passenger
        
        last_entity = next_entity
      end
    end
  end

end
