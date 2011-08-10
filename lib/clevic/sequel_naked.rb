require 'sequel'

module Sequel
  module Plugins
    # Fix the naked call to do the following:
    # - remove the row_proc
    # - remove the model method, or make it return nil
    # - fix the destroy method. Not sure what this means right now.
    module Naked
      def self.configure(model, options = {})
        model.instance_eval do
          # store model-related stuff here
        end
      end

      module ClassMethods
        def inherited(subclass)
          super
        end

        def naked( *args )

        end
      end

      module InstanceMethods
      end
    end
  end
end
