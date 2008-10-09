require File.dirname(__FILE__) + '/test_helper'

class TestModelIndex < Test::Unit::TestCase
  def self.startup
  end
  
  def self.shutdown
  end
  
  def setup
    @model = Qt::StandardItemModel.new( 4, 4 )
    ( 0...@model.row_count ).each do |i|
      ( 0...@model.column_count ).each do |j|
        @model.set_item( i, j, Qt::StandardItem.new( "location: (#{i},#{j})" ) )
      end
    end
    @zero_index = @model.create_index(0,0)
  end
  
  def teardown
  end
  
  should "be valid" do
    assert @zero_index.valid?
  end
  
  should_eventually "be invalid" do
    mi = @model.create_index( @model.row_count+1, @model.column_count+1 )
    assert !mi.valid?
  end
  
  should 'be an invalid copy of an invalid index' do
    choppy = Qt::ModelIndex.invalid.choppy
    assert !choppy.valid?
  end
  
  should "be a valid exact copy" do
    choppy = @zero_index.choppy
    assert choppy.valid?
  end

  should 'be an invalid copy' do
    choppy = @zero_index.choppy( :row => @model.row_count )
    assert !choppy.valid?, "choppy: #{choppy.inspect}"
    
    choppy = @zero_index.choppy( :column => @model.column_count )
    assert !choppy.valid?
  end
  
  should 'be a copy with a changed row and column, from hash' do
    choppy = @zero_index.choppy( :row => 1, :column => 2)
    assert_equal 1, choppy.row, choppy.inspect
    assert choppy.valid?, choppy.inspect
    assert_equal 2, choppy.column, choppy.inspect
  end

  should 'be a choppy with incremented row and column, from block' do
    choppy = @zero_index.choppy do |i|
      i.row += 1
      i.column += 2
    end
    assert choppy.valid?
    assert_equal 1, choppy.row
    assert_equal 2, choppy.column
  end
  
  should 'be a copy with changed row and column, from parameters' do
    choppy = @zero_index.choppy(3,0)
    assert choppy.valid?
    assert_equal 3, choppy.row
    assert_equal 0, choppy.column
  end
  
  should 'raise an exception because parameters are wrong' do
    assert_raise TypeError do
      @zero_index.choppy( 3 )
    end
  end
  
  should 'be a copy with decremented row and column, from block' do
    two_index = @model.create_index(2,2)
    
    choppy = two_index.choppy do |i|
      i.row -= 1
      i.column -= 2
    end
    assert choppy.valid?
    assert_equal 1, choppy.row
    assert_equal 0, choppy.column
  end

  should 'be a copy with changed row and column, from block' do
    choppy = @zero_index.choppy do |i|
      i.row = 3
      i.column = 2
    end
    assert choppy.valid?
    assert_equal 3, choppy.row
    assert_equal 2, choppy.column
  end

  should 'be a copy with changed row and column, from instance_eval' do
    choppy = @zero_index.choppy do
      row 3
      column 2
    end
    assert choppy.valid?
    assert_equal 3, choppy.row
    assert_equal 2, choppy.column
  end
end
