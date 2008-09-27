require File.dirname(__FILE__) + '/spec_helper.rb'
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

describe 'initialise database', :shared => true do
  before :all do
    @onebase = OneBase.new
    ActiveRecord::Migration.verbose = false
    CreatePassengers.up
    CreateFakePassengers.up
  end

  after :all do
    CreateFakePassengers.down
    CreatePassengers.down
    @onebase.feenesh
  end
end

describe TableSearcher, "on initialisation" do
  it_should_behave_like 'initialise database'
  before :each do
    @simple_search_criteria = MockSearchCriteria.new
    @name_field = Clevic::Field.new( :name, Passenger, {} )
    @id_order_attribute = OrderAttribute.new( Passenger, 'id' )
  end

  it "should have a matching field attribute on construction" do
    ts = TableSearcher.new( Passenger, [@id_order_attribute], @simple_search_criteria, @name_field )
    ts.field.attribute.should == @name_field.attribute
  end

  it "should throw an exception when called with no order attributes" do
    lambda do
      TableSearcher.new( Passenger, nil, @simple_search_criteria, @name_field )
    end.should raise_error( RuntimeError )
  end

  it "should throw an exception when called with an empty collection of order attributes" do
    lambda do
      TableSearcher.new( Passenger, [], @simple_search_criteria, @name_field )
    end.should raise_error( RuntimeError )
  end
    
  it "should throw an exception when called with no field" do
    lambda do
      TableSearcher.new( Passenger, [@id_order_attribute], @simple_search_criteria, nil )
    end.should raise_error( RuntimeError )
  end
  
end

describe TableSearcher, " when searching" do
  it_should_behave_like 'initialise database'
  
  before :all do
    @all_passengers = Passenger.find( :all, :conditions => [ 'flight = ?', CreateFakePassengers::FLIGHTS[0] ], :order => :id )
    @name_field = Clevic::Field.new( :name, Passenger, {} )
    @id_order_attribute = OrderAttribute.new( Passenger, 'id' )
    @flight_field = Clevic::Field.new( :flight, Passenger, {} )
  end  

  before :each do
    @simple_search_criteria = MockSearchCriteria.new
    @simple_search_criteria.search_text = CreateFakePassengers::FLIGHTS[0]
    @passenger_generator = Generator.new( @all_passengers )
  end
  
  after :each do
  end

  it "should have #{CreateFakePassengers::MAX_PASSENGERS} passengers" do
    Passenger.count.should == CreateFakePassengers::MAX_PASSENGERS
  end

  it "should do more granular testing"
  
  it "should find the first record correctly" do
    @simple_search_criteria.from_start = true
    table_searcher = TableSearcher.new( Passenger, [@id_order_attribute], @simple_search_criteria, @flight_field )
    
    @first = table_searcher.search( nil )
    @all_passengers.first == @first
  end
  
  it "should find next records correctly" do
    @simple_search_criteria.from_start = false
    table_searcher = TableSearcher.new( Passenger, [@id_order_attribute], @simple_search_criteria, @flight_field )
    
    # fetch records one by one, starting from the one after the first one, and compare them
    while next_entity = table_searcher.search( @passenger_generator.next )
      passenger = @passenger_generator.next
      passenger.should == next_entity
      passenger.should_not == @all_passengers.first
      last_entity = next_entity
    end
  end
end
