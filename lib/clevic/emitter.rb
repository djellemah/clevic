require 'set'

module Clevic
  module Emitter
    def self.included( base )
      base.extend( ClassMethods )
    end
    
    module ClassMethods
      def emitter( emitter_name )
        line, st = __LINE__, <<-EOF
          def #{emitter_name}_listeners
            @#{emitter_name}_listeners ||= Set.new
          end
          
          # If msg is provided, yield to stored block.
          # If block is provided, store it for later.
          def emit_#{emitter_name}( *args, &notifier_block )
            if block_given?
              #{emitter_name}_listeners << notifier_block
            else
              puts "emit_#{emitter_name} called with " + args.inspect
              #{emitter_name}_listeners.each do |notify|
                notify.call( *args )
              end
            end
          end
          
          def remove_#{emitter_name}( &notifier_block )
            #{emitter_name}_listeners.delete( notifier_block )
          end
        EOF
        class_eval st, __FILE__, line + 1
      end
    end
  end
end
