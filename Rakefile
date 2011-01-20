%w[rubygems rake rake/clean fileutils newgem rubigen].each { |f| require f }
require File.dirname(__FILE__) + '/lib/clevic/version.rb'

# Generate all the Rake tasks
# Run 'rake -T' to see list of generated tasks (from gem root directory)
$hoe = Hoe.new('clevic', Clevic::VERSION::STRING) do |p|
  p.developer('John Anderson', 'panic@semiosix.com')
  p.changes              = p.paragraphs_of("History.txt", 0..1).join("\n\n")
  p.rubyforge_name       = p.name # TODO this is default value
  p.description          = "SQL table GUI with Qt, Swing, Sequel"
  p.extra_deps         = [
    ['activesupport','>= 2.0.2'],
    ['fastercsv', '>=1.2.3'],
    ['gather', '>=0.0.4'],
    ['hashery', '>=1.3.0'],
    ['andand', '>= 1.3.0'],
    ['sequel', '>= 3.8.0'],
    ['hpricot', '>= 0.8.1'],
    ['io-like', '>= 0.3.0']
    # This isn't always installed from gems
    #~ ['qtruby4', '>=1.4.9']
    # bsearch can't be installed from gems
  ]
  p.extra_dev_deps = [
    ['newgem', ">= #{::Newgem::VERSION}"]
  ]
  
  p.clean_globs |= %w[**/.DS_Store tmp *.log]
  path = (p.rubyforge_name == p.name) ? p.rubyforge_name : "\#{p.rubyforge_name}/\#{p.name}"
  p.remote_rdoc_dir = File.join(path.gsub(/^#{p.rubyforge_name}\/?/,''), 'rdoc')
  p.rsync_args = '-av --delete --ignore-errors'
end

require 'newgem/tasks' # load /tasks/*.rake
Dir['tasks/**/*.rake'].each { |t| load t }
