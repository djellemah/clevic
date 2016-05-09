require_relative 'spec_helper.rb'
require_relative 'fixtures.rb'

require 'clevic/table_model.rb'

# need to set up a test DB, and test data for this
describe Clevic::TableModel do
  before :all do Fixtures.up end
  after :all do Fixtures.down end

  before :each do
    @table_model = Clevic::TableModel.new( )
  end

  it 'not have new record on empty' do
    pending "not implemented"

    # without auto_new
    (0...Passenger.count).each do |i|
      @table_model.delete_at 0
      @table_model.delete_at 0
      @table_model.delete_at 0
    end
    @table_model.size.should == 0
  end

  it 'have new record on empty' do
    pending "not implemented"

    #with auto_new
    @table_model = @table_model.renew( :auto_new => true )
    @table_model.options.should_not have_key( :auto_new )
    (0...Passenger.count).each do |i|
      @table_model.delete_at 0
      @table_model.delete_at 0
      @table_model.delete_at 0
    end

    @table_model.size.should == 1
  end

end
