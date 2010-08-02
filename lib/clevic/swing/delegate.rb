require 'clevic/delegate'

module Clevic

class Delegate
  def initialize( field )
    @field = field
    @message_receivers = Set.new
  end
  
  def show_message( msg, &block )
    if block_given?
      @message_receivers << block
    else
      @message_receivers.each do |receiver|
        receiver.call( msg )
      end
    end
  end
end

end
