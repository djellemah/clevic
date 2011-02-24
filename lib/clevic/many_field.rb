module Clevic

  # Preliminary code for multi-valued fields. Not working yet.
  module ManyField
    # x_to_many fields are by definition collections of other entities
    def many( &block )
      if block
        many_view( &block )
      else
        many_view do |mb|
          # TODO should fetch this from one of the field definitions
          mb.plain related_attribute
        end
      end
    end
    
    def many_builder
      @many_view.builder
    end
    
    def many_fields
      many_builder.fields
    end
    
    # return an instance of Clevic::View that represents the many items
    # for this field
    def many_view( &block )
      @many_view ||= View.new( :entity_class => related_class, &block )
    end
  end

end
