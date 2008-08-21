require 'clevic.rb'

class Subscriber
  post_default_ui do
    plain :password
    hide :password_salt
    hide :password_hash
  end
end
