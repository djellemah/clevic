require 'active_record'

# these will normally be defined fully in the model definition file
# $options[:database] to be defined with the models
$options ||= {}
$options[:adapter]  ||= 'postgresql'
$options[:host] ||= 'localhost'
$options[:username] ||= ''
$options[:password] ||= ''

ActiveRecord::Base.establish_connection( $options )
ActiveRecord::Base.logger = Logger.new(STDOUT) if $options[:verbose]
#~ ActiveRecord.colorize_logging = false

puts "using database #{ActiveRecord::Base.connection.raw_connection.db}" if $options[:debug]

# workaround for the date freeze issue
class Date
  def freeze
    self
  end
end

