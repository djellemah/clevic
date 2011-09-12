require File.dirname(__FILE__) + '/test_helper'
require 'clevic/table_model.rb'

# need to set up a test DB, and test data for this
class TestTableModel < Test::Unit::TestCase
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
