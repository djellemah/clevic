require 'active_support/core_ext/array/extract_options.rb'

module Sequel
  module Plugins
    module ArFinder
      # model is the model class. The rest is whatever I want
      def self.configure(model)
        model.instance_eval do
          # store model-related stuff here
        end
      end
      
      module ClassMethods
        # Copy the necessary class instance variables to the subclass.
        def inherited(subclass)
          super
          #~ store = @cache_store
          #~ ttl = @cache_ttl
          #~ cache_ignore_exceptions = @cache_ignore_exceptions
          #~ subclass.instance_eval do
            #~ @cache_store = store
            #~ @cache_ttl = ttl
            #~ @cache_ignore_exceptions = cache_ignore_exceptions
          #~ end
        end
        
        def lit_if_string( arg )
          if arg.is_a?( String )
            arg.lit
          else
            arg
          end
        end
        
        # Basically, we're translating from AR's hash options
        # to Sequel's method algebra
        def translate( options )
          options.inject( dataset ) do |dataset, (key, value)|
            case key
              when :limit; dataset.limit( value, nil )
              when :offset
                # bit of a hack to get around Sequels refusal
                # to do offset without limit
                dataset.limit( options[:limit] || :all, value )
                
              when :order; dataset.order( lit_if_string( value ) )
              when :conditions
                dataset.filter( lit_if_string( value ) )
                
              else
                raise "#{key} not implemented"
            end
          end
        end
        
        def find_ar( *args )
          # copied direct from ActiveRecord::Base.find
          options = args.extract_options!
          #~ validate_find_options(options)
          #~ set_readonly_option!(options)
          case args.first
            when :first
              translate(options).first
              
            when :last
              translate(options).last
              
            when :all
              translate(options).all
              
            else
              if args.size == 1
                translate(options).filter( :id => args.first ).first
              else
                translate(options).filter( :id => args ).all
              end
          end
        end
        
        def count_ar( *args )
          options = args.extract_options!
          attribute = args.first
          
          dataset = translate( options )
          
          unless attribute.nil?
            dataset = dataset.select( attribute )
          end
          dataset.count
        end
        
      end
      
      module InstanceMethods
      end
    end
  end
end
