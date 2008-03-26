# set up defaults
# $options[:database] to be defined with the models

$options ||= []
$options[:adapter]  ||= 'postgresql'
$options[:host] ||= 'localhost'
$options[:username] ||= 'panic'
$options[:password] ||= ''

ActiveRecord::Base.establish_connection( $options )
