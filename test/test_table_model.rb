require File.dirname(__FILE__) + '/test_helper'
require 'clevic/table_model.rb'

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
class TestTableModel < Test::Unit::TestCase
  def self.startup
    PopulateCachePassengers.up
  end
  
  def self.shutdown
    PopulateCachePassengers.down
  end
  
  
  def setup
    @table_model = Clevic::TableModel.new( )
  end
  
  def teardown
  end
  
  should "be an empty shell" do
    assert true
  end
  
  should_eventually 'not have new record on empty' do
    # without auto_new
    (0...Passenger.count).each do |i|
      @table_model.delete_at 0
      @table_model.delete_at 0
      @table_model.delete_at 0
    end
    assert_equal 0, @table_model.size
  end
  
  should_eventually 'have new record on empty' do
    #with auto_new
    @table_model = @table_model.renew( :auto_new => true )
    assert !@table_model.options.has_key?( :auto_new ), "CacheTable should not have :auto_new in options"
    (0...Passenger.count).each do |i|
      @table_model.delete_at 0
      @table_model.delete_at 0
      @table_model.delete_at 0
    end
    
    assert_equal 1, @table_model.size
  end
  
end
