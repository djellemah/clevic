require File.dirname(__FILE__) + '/test_helper'
require 'clevic/order_attribute.rb'

class Dummy < ActiveRecord::Base
end

# need to set up a test DB, and test data for this
class TestOrderAttribute < Test::Unit::TestCase
  def setup
  end
  
  def teardown
  end
  
  def test_reverse
    oa = OrderAttribute.new Dummy, 'id'
    assert_equal :asc, oa.reverse( :desc )
    assert_equal :desc, oa.reverse( :asc )
    assert_raise( RuntimeError ) { oa.reverse( :something_wrong ) }
  end
  
  # Test that initialisation was OK
  def test_equal
    oa1 = OrderAttribute.new Dummy, 'id'
    oa2 = OrderAttribute.new Dummy, 'id'
    assert_equal oa1, oa2
    assert_equal oa1.to_sql, 'dummies.id asc'
    assert_equal oa1.to_reverse_sql, 'dummies.id desc'
    assert_equal oa1.attribute.to_sym, oa1.to_sym
    
    assert_equal oa2.to_sql, 'dummies.id asc'
    assert_equal oa2.to_reverse_sql, 'dummies.id desc'
  end
  
  def test_parse_default
    oa_asc = OrderAttribute.new Dummy, "name"
    assert_equal 'name', oa_asc.attribute
    assert_equal :asc, oa_asc.direction
  end
  
  def test_parse_desc
    oa_desc = OrderAttribute.new Dummy, "name desc"
    assert_equal 'name', oa_desc.attribute
    assert_equal 'name', oa_desc.to_s
    assert_equal :desc, oa_desc.direction
    assert_equal oa_desc.to_sql, 'dummies.name desc'
    assert_equal 'dummies.name asc', oa_desc.to_reverse_sql
    
    oa_desc = OrderAttribute.new Dummy, "dummies.name desc"
    assert_equal 'name', oa_desc.attribute
    assert_equal :desc, oa_desc.direction
    assert_equal oa_desc.to_sql, 'dummies.name desc'
  end
  
  def test_parse_table
    oa_with_table = OrderAttribute.new Dummy, 'dummies.name asc'
    assert_equal 'name', oa_with_table.attribute
    assert_equal :asc, oa_with_table.direction
    assert_equal oa_with_table.to_sql, 'dummies.name asc'
  end
  
end
