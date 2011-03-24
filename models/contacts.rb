require 'clevic.rb'

$options = {} unless defined?( $options )

$options[:username] = ENV['PGUSER'] || ENV['USER']
$options[:host] = ENV['PGHOST'] || 'localhost'

puts "$options: #{$options.inspect}"

if RUBY_PLATFORM == 'java'
  constring = "jdbc:postgresql://#{$options[:host]}/contacts?user=#{$options[:username] || 'contacts'}"
  puts "constring: #{constring.inspect}"
  Sequel.connect( constring )
else
  Sequel.connect( "postgres://#{$options[:host]}/contacts?user=#{$options[:username] || 'contacts'}" )
end

# for irb testing when we don't need the UI
unless defined?( Clevic::Record )
module Clevic
  module Record
    def self.define_ui( *args )
    end
  end
end
end

class Contact < Sequel::Model
  many_to_many :tags
  
  def tags=( ary )
    to_add = ary - tags
    to_remove = tags - ary
    to_remove.each{|x| remove_tag x}
    to_add.each{|x| add_tag x}
  end
  
end

class ContactTags < Clevic::View
  entity_class Contact
  
  attr_accessor :entity
  
  def define_ui
    model_builder do |mb|
      mb.plain :date, :sample => '88-WWW-99'
      mb.plain :name
      mb.tags :tags do |tf|
        tf.display {|x| x.map(&:name).join(',') }
        tf.many do |mnb|
          mnb.check :contacts do |f|
            f.display do |arg|
              arg.include?( f.model.one )
            end
            
            f.class_eval do
              def display=( entity, arg )
                puts "field display self: #{self.inspect}"
                puts "field display= #{arg}"
              end
            end
          end
          
          #~ mnb.fields[:contacts] = Clevic::Field.new( :contacts, entity_class, {} ).tap do |f|
            #~ f.delegate = Clevic::BooleanDelegate.new( f )
            #~ f.display do |arg|
              #~ arg.include?( f.model.one )
            #~ end
          #~ end
          
          mnb.plain :name
        end
      end
      mb.text :email
      
      mb.records     :order => 'name, id'
    end
  end
  
  def linked
    puts "linked"
    @linked
  end
  
  def linked=( value )
    puts "linked=#{value}"
    @linked = value
  end

  def self.meta
    @meta ||= {
      :linked => ModelColumn.new( :linked, :type => :boolean ),
      :contacts => ModelColumn.new( :contacts, :type => :boolean ),
    }
  end
end

class Tag < Sequel::Model
  many_to_many :contacts
  
  include Clevic::Record
  
  # define how fields are displayed
  define_ui do
    plain       :name
    plain       :category
    
    records  :order => 'category,name'
  end

end

class ContactTag < Sequel::Model( :contacts_tags )
  many_to_one :contact
  many_to_one :tag
end
