require 'sequel'

module Sequel
  module Plugins
    # This is used by Clevic to talk to models. It's here because
    # I'd rather keep some kind of layer in case it's necessary
    # to become more pluggable in relation to ORM frameworks.
    module Clevic
      def self.configure(model, options = {})
        model.instance_eval do
          # store model-related stuff here
        end
      end

      module ClassMethods
        # Copy the necessary class instance variables to the subclass.
        def inherited(subclass)
          super
        end

        # This doesn't really belong here, but I don't want to make 
        # a whole new plugin.
        def table_exists?
          db.table_exists?( implicit_table_name )
        end

        # Hmm, maybe these need to go in a different plugin
        def column_names
          columns
        end

        # Getting heavy enough, yet?
        def reflections
          association_reflections 
        end

        def attribute_names
          columns + reflections.keys
        end

        def has_attribute?( attribute )
          attribute_names.include?( attribute )
        end

      end

      module InstanceMethods
        # This should also go in another plugin
        def changed?
          modified?
        end

        def readonly?
          false
        end

        def new_record?
          new?
        end
      end
    end
  end
end

Sequel::Model.plugin :clevic

# This doesn't seem to work inside the plugin
module Sequel
  class Model
    class Errors
      def invalid?( field_name )
        self.has_key?( field_name )
      end
    end
  end
end
