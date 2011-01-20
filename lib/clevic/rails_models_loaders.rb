require 'active_support'

def load_rails_models( root, config, models )
  # initialize Rails
  load config / 'environment.rb'
  require 'initializer.rb'
  Rails::Initializer.run do |config|
    config.frameworks -= [ :action_mailer, :action_pack, :active_resource ]
  end
  
  # load lib/ files for the rails project
  $: << ( root / 'lib' ).realpath.to_s
  ( root / 'lib' ).children.each do |filename|
    load filename if filename.file?
  end

  # include Dirty if it isn't already
  begin
    ActiveRecord::Dirty
  rescue NameError
    ActiveRecord::Base.send(:include, ActiveRecord::Dirty)
  end
  
  # load models
  models.find do |dir_entry|
    # don't load directory entries
    next unless dir_entry.file?
    # only load .rb files
    next unless dir_entry.basename.to_s =~ /\.rb$/
    begin
      load dir_entry
    rescue Exception => e
      puts "Error loading #{dir_entry.basename.to_s}: #{e.message}"
      puts e.backtrace
    end
  end
  
  # include the Clevic::Record module in each descendant of
  # the entity class so that the default views will be created.
  subclasses( Clevic.base_entity_class ).each do |model|
    if model.table_exists?
      model.send :include, Clevic::Record unless model.abstract_class?
    end
  end
end

def maybe_load_rails_models
  config = pathname / 'config'
  app = pathname / 'app'
  models = app / 'models'
  # check if this is a Rails directory
  if config.exist? && app.exist? && models.exist?
    # this is probably a Rails project"
    load_rails_models( pathname, config, models )
  end  
end
