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
  if false
    # db connection
    Clevic::DbOptions.connect( $options ) do
      # use a different db for testing, so real data doesn't get broken.
      if options[:database].nil? || options[:database].empty?
        database( debug? ? :accounts_test : :accounts )
      else
        database options[:database]
      end
      # for AR
      #~ adapter :postgresql
      # for Sequel
      adapter :postgres
      username options[:username].blank? ? 'contacts' : options[:username]
    end
  else
    require 'sequel'
    Sequel.connect( "postgres://#{$options[:host]}/contacts?user=#{$options[:username] || 'contacts'}" )
  end
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
  
  include Clevic::Record
  
  define_ui do
    plain :date, :sample => '88-WWW-99'
    plain :name
    tags :tags do
      display {|x| x.map(&:name).join(',') }
      many do |mb|
        mb.plain :name
      end
    end
    text :email
    
    records     :order => 'name, id'
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
