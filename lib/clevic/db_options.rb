# set up defaults
# $options[:database] to be defined with the models
require 'active_record'

$options ||= {}
$options[:adapter]  ||= 'postgresql'
$options[:host] ||= 'localhost'
$options[:username] ||= 'panic'
$options[:password] ||= ''

ActiveRecord::Base.establish_connection( $options )
ActiveRecord::Base.logger = Logger.new(STDOUT) if $options[:debug]
#~ ActiveRecord.colorize_logging = false

# workaround for the date freeze issue
class Date
  def freeze
    self
  end
end

