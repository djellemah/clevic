require 'clevic.rb'

class Subscriber
  def self.post_default_ui( model_builder )
    model_builder.instance_eval do
      plain :password
      hide :password_salt
      hide :password_hash
    end
  end
end
