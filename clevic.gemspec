# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'clevic/version'

Gem::Specification.new do |spec|
  spec.name          = "clevic"
  spec.version       = Clevic::VERSION
  spec.authors       = ["John Anderson"]
  spec.email         = ["panic@semiosix.com"]
  spec.summary       = %q{SQL table GUI with Qt / Java Swing and Sequel.}
  spec.description   = %q{SQL table GUI with Qt / Java Swing and Sequel.}
  spec.homepage      = "http://github.com/djellemah/clevic"
  spec.license       = "MIT"

  spec.files         = File.read('Manifest.txt').split
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"

  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'faker'
  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency 'pry'

  spec.add_dependency 'gather', '>=0.0.8'
  spec.add_dependency 'fastandand'
  spec.add_dependency 'sequel', '>= 4.10.0'
  spec.add_dependency 'bsearch', '>=1.5.0'

  # for html paste parsing
  spec.add_dependency 'hpricot', '>= 0.8.1'

  # for JRuby clipboard handling
  spec.add_dependency 'io-like', '>= 0.3.0'

  # for Qt
  spec.add_dependency 'qtbindings', '>=4.6.3'
  spec.add_dependency 'qtext', '>=0.6.9'
end
