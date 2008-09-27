require File.dirname(__FILE__) + '/test_helper'
require 'activerecord'
require 'sqlite3'

class Passenger < ActiveRecord::Base
end

class CreatePassengers < ActiveRecord::Migration
  def self.up
    create_table :passengers do |t|
      t.string :name
      t.string :flight
      t.integer :row
      t.string :seat
    end
    Passenger.reset_column_information
    Passenger.create :name => 'John Anderson', :flight => 'EK211', :row => 36, :seat => 'A'
    Passenger.create :name => 'Genie', :flight => 'CA001', :row => 1, :seat => 'A'
    Passenger.create :name => 'Aladdin', :flight => 'CA001', :row => 2, :seat => 'A'
  end
  
  def self.down
  end
end

# need to set up a test DB, and test data for this
class TestCacheTable < Test::Unit::TestCase
  # I don't really want to run this before every test case
  def setup
    @db_name = 'test_cache_table.sqlite3'
    File.unlink @db_name if File.exists? @db_name
    @db = SQLite3::Database.new( @db_name )
    @db_options = Clevic::DbOptions.connect do |dbo|
      dbo.database @db_name
      dbo.adapter :sqlite3
    end
    CreatePassengers.migrate :up
    @cache_table = CacheTable.new( Passenger )
    @passenger_count = @db.execute( 'select count(*) from passengers' )[0][0].to_i
  end
  
  def teardown
    File.unlink @db_name
  end
  
  # Test that initialisation was OK
  def test_init
    assert_equal @db_options.database, @db_name
    assert_equal @passenger_count, Passenger.count
  end
  
  # test that cache is initially empty
  def test_cache_loading
    assert_equal Passenger.count, @cache_table.sql_count
    assert_equal Passenger.count, @cache_table.size

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
  
  def test_default_order_attributes
    oa = OrderAttribute.new( Passenger, 'id' )
    assert_equal oa, @cache_table.order_attributes[0]
  end
  
  def test_parse_order_attributes
    order_string = 'name desc, passengers.flight asc, row'
    ct = CacheTable.new Passenger, :order => order_string
    assert_equal OrderAttribute.new( Passenger, 'name desc' ), ct.order_attributes[0]
    assert_equal OrderAttribute.new( Passenger, 'flight' ), ct.order_attributes[1]
    assert_equal OrderAttribute.new( Passenger, 'row asc' ), ct.order_attributes[2]
  end
  
  def test_auto_new_on_delete
    # without auto_new
    (0...Passenger.count).each do |i|
      @cache_table.delete_at 0
      @cache_table.delete_at 0
      @cache_table.delete_at 0
    end
    assert_equal 0, @cache_table.size
    
    #with auto_new
    @cache_table = @cache_table.renew( :auto_new => true )
    assert !@cache_table.options.has_key?( :auto_new ), "CacheTable should not have :auto_new in options"
    (0...Passenger.count).each do |i|
      @cache_table.delete_at 0
      @cache_table.delete_at 0
      @cache_table.delete_at 0
    end
    
    assert_equal 1, @cache_table.size
  end
  
  #~ def 
  
end
