require 'active_support'
require 'active_support/core_ext/array/extract_options.rb'

module Sequel
  class Dataset
    # Basically, we're translating from AR's hash options
    # to Sequel's method algebra, and returning the resulting
    # dataset.
    def translate( options )
      # recursively send key-value pairs to self
      # and return the result
      options.inject( self ) do |dataset, (key, value)|
        case key
          when :limit; dataset.limit( value, nil )
          when :offset
            # workaround for Sequel's refusal to do offset without limit
            # not sure we need :all for >= 3.13.0
            dataset.limit( options[:limit] || :all, value )
          
          when :order
            orders = value.split(/, */ ).map do |x|
              case x
              when /^(\w+) +(asc|desc)$/i
                $1.to_sym.send( $2 )
                
              when /^\w+$/i
                x.to_sym
              
              else
                x.lit
                
              end
            end
            dataset.order( *orders )
          
          when :conditions
            # this translation is not adequate for all use cases of the AR api
            # specifically where value contains a SQL expression
            unless value.nil?
              possible_literal =
              if value.is_a?( String )
                value.lit
              else
                value
              end
              
              dataset.filter( possible_literal ) 
            end
          
          when :include
            # this is the class to join
            joined_class = eval( model.reflections[value][:class_name] )
            dataset.join_table(
              :inner,
              joined_class,
              joined_class.primary_key => model.reflections[value][:key]
            ).select( model.table_name.* )
            
          else
            raise "#{key} not implemented"
        # make sure at least it's unchanged, in case options is empty
        end || dataset
      end
      
      rescue Exception => e
        raise RuntimeError, "#{self} #{options.inspect} #{e.message}", caller(0)
    end
  end
  
  module Plugins
    module ArMethods
      # plugin :ar_methods calls this.
      # model is the model class. The rest is whatever options are
      # in the plugin call, possibility for
      #  plugin :ar_methods :override_sequel => true
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
        
        def translate( options )
          dataset.translate( options )
        end
        
        def find_ar( *args )
          # copied from ActiveRecord::Base.find
          options = args.extract_options!
          #~ validate_find_options(options)
          #~ set_readonly_option!(options)
          
          case args.first
            when :first
              dataset.translate(options).first
              
            when :last
              dataset.translate(options).last
              
            when :all
              dataset.translate(options).all
              
            else
              if args.size == 1
                dataset.translate(options).filter( :id.qualify( table_name ) => args.first ).first
              else
                dataset.translate(options).filter( :id.qualify( table_name ) => args ).all
              end
          end
        end
        
        def count_ar( *args )
          options = args.extract_options!
          attribute = args.first
          
          dataset = dataset.translate( options )
          
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
