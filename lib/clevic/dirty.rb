begin
  ActiveRecord::Dirty
rescue NameError

module ActiveRecord
  # Define ActiveRecord::Dirty if it isn't already defined by ActiveRecord,
  # which it is in 2.1 and up.
  module Dirty
    def self.included(base)
      base.attribute_method_suffix '_changed?', '_change', '_original'
      base.alias_method_chain :read_attribute,  :dirty
      base.alias_method_chain :write_attribute, :dirty
      base.alias_method_chain :save,            :dirty
    end

    # Do any attributes have unsaved changes?
    #   person.changed? # => false
    #   person.name = 'bob'
    #   person.changed? # => true
    def changed?
      !changed_attributes.empty?
    end

    # List of attributes with unsaved changes.
    #   person.changed # => []
    #   person.name = 'bob'
    #   person.changed # => ['name']
    def changed
      changed_attributes.keys
    end

    # Map of changed attrs => [original value, new value]
    #   person.changes # => {}
    #   person.name = 'bob'
    #   person.changes # => { 'name' => ['bill', 'bob'] }
    def changes
      changed.inject({}) { |h, attr| h[attr] = attribute_change(attr); h }
    end


    # Clear changed attributes after they are saved.
    def save_with_dirty(*args) #:nodoc:
      save_without_dirty(*args)
    ensure
      changed_attributes.clear
    end

    private
    
    # Map of change attr => original value.
    def changed_attributes
      @changed_attributes ||= {}
    end


    # Wrap read_attribute to freeze its result.
    def read_attribute_with_dirty(attr)
      read_attribute_without_dirty(attr).freeze
    end

    # Wrap write_attribute to remember original attribute value.
    def write_attribute_with_dirty(attr, value)
      attr = attr.to_s

      # The attribute already has an unsaved change.
      unless changed_attributes.include?(attr)
        old = read_attribute(attr)

        # Remember the original value if it's different.
        changed_attributes[attr] = old unless old == value
      end

      # Carry on.
      write_attribute_without_dirty(attr, value)
    end


    # Handle *_changed? for method_missing.
    def attribute_changed?(attr)
      changed_attributes.include?(attr)
    end

    # Handle *_change for method_missing.
    def attribute_change(attr)
      [changed_attributes[attr], __send__(attr)] if attribute_changed?(attr)
    end

    # Handle *_original for method_missing.
    def attribute_original(attr)
      attribute_changed?(attr) ? changed_attributes[attr] : __send__(attr)
    end
  end # module Dirty

  # put this here so it's part of the compatibility rescue block.
  class Base
    include ActiveRecord::Dirty
  end

end # module ActiveRecord

end # rescue
