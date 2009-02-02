require File.dirname(__FILE__) + '/test_helper'

class PopulateCachePassengers < ActiveRecord::Migration
  def self.up
    Passenger.create :name => 'John Anderson', :flight => Flight.find_by_number('EK211'), :row => 36, :seat => 'A', :nationality => 'UAE'
    Passenger.create :name => 'Genie', :flight => Flight.find_by_number('CA001'), :row => 1, :seat => 'A', :nationality => 'Canada'
    Passenger.create :name => 'Aladdin', :flight => Flight.find_by_number('CA001'), :row => 2, :seat => 'A', :nationality => 'Canada'
  end
  
  def self.down
    Passenger.delete :all
  end
end

# need to set up a test DB, and test data for this
class TestCacheTable < Test::Unit::TestCase
  def self.startup
    PopulateCachePassengers.up
  end
  
  def self.shutdown
    PopulateCachePassengers.down
  end
  
  
  def setup
    @cache_table = CacheTable.new( Passenger )
  end
  
  def teardown
  end
  
  def test_passenger_count
    assert_equal 3, Passenger.count
  end
  
  should "have a sql_count equal to number of records" do
    assert_equal Passenger.count, @cache_table.sql_count
  end
  
  should "have a size equal to number of records" do
    assert_equal Passenger.count, @cache_table.size
  end
  
  def test_cache_loading
    # test not yet cached
    (0...Passenger.count).each do |i|
      assert @cache_table.cached_at?(i) == false, "record #{i} should not be cached yet"
    end
    
    # test cache retrieval
    (0...Passenger.count).each do |i|
      assert @cache_table[i] == Passenger.find( :first, :offset => i ), "#{i}th cached record is not #{i}th db record"
    end
  end
  
  def test_preload_limit_1
    @cache_table.preload_limit 1 do
      assert !@cache_table[0].nil?, 'First object should not be nil'
      (1...Passenger.count).each do |i|
        assert !@cache_table.cached_at?(i), "#{i}th object should be nil"
      end
    end
  end

  # make sure preloads are done
  def test_preload_limit_default
    (0...Passenger.count).each do |i|
      assert !@cache_table.cached_at?(i), "record #{i} should not be cached yet"
    end
    @cache_table[0]
    (0...Passenger.count).each do |i|
      assert @cache_table.cached_at?(i), "#{i}th object should not be nil"
    end
  end
  
  should 'have id as a default order attribute' do
    oa = OrderAttribute.new( Passenger, 'id' )
    assert_equal oa, @cache_table.order_attributes[0]
  end
  
  def test_parse_order_attributes
    order_string = 'name desc, passengers.nationality asc, row'
    ct = CacheTable.new Passenger, :order => order_string
    assert_equal OrderAttribute.new( Passenger, 'name desc' ), ct.order_attributes[0]
    assert_equal OrderAttribute.new( Passenger, 'nationality' ), ct.order_attributes[1]
    assert_equal OrderAttribute.new( Passenger, 'row asc' ), ct.order_attributes[2]
  end
  
  should 'return nil for a nil parameter' do
    assert_nil @cache_table.index_for_entity( nil )
  end
    
  should 'return nil for an empty set' do
    cache_table = @cache_table.renew( :conditions => "nationality = 'nothing'" )
    assert_nil cache_table.index_for_entity( Passenger.find( :first ) )
  end
  
  def test_index_for_entity
    # test in ascending order
    first_passenger = Passenger.find :first
    index = @cache_table.index_for_entity( first_passenger )
    assert_equal 0, index, 'first passenger should have an index of 0'
    
    # test in descending order
    @cache_table = @cache_table.renew( :order => 'id desc' )
    last_passenger = Passenger.find :first, :order => 'id desc'
    assert_equal 0, @cache_table.index_for_entity( last_passenger ), "last passenger in reverse order should have an index of 0"
    
    # test with two order fields
    @cache_table = @cache_table.renew( :order => 'nationality, row' )
    passenger = Passenger.find :first, :order => 'nationality, row'
    assert_equal 0, @cache_table.index_for_entity( passenger ), "passenger in (nationality, row) order should have an index of 0"
  end
end
