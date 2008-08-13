require 'clevic.rb'

class Subscriber
  def self.build( model_builder )
    require 'pp'
    pp model_builder.fields.inspect
    model_builder.instance_eval do
      plain :password
      hide :password_salt
      hide :password_hash
    end
  end
end
