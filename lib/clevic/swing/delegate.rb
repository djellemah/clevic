require 'clevic/delegate'

module Clevic

  class Delegate
    def initialize( field )
      @field = field
      @message_receivers = Set.new
    end

    # FIXME this must actually show a message, and 
    # the Qt code must use it too
    def show_message( msg, &block )
      if block_given?
        @message_receivers << block
      else
        @message_receivers.each do |receiver|
          receiver.call( msg )
        end
      end
    end

    # workaround for broken JTable editing starts
    def needs_pre_selection?
      false
    end

    # Return something useful if this should use the default GUI framework
    # mechanism for table editing. Default is false, so native framework
    # won't be used. For Java/Swing, this would return the a class object
    # indicating the type of data, eg java.lang.Boolean, or java.lang.String
    # or something from JTable.setDefaultEditor
    def native
      false
    end

    def inspect
      "<#{self.class.name} native=#{native} needs_pre_selection=#{needs_pre_selection?}>"
    end
  end

end
