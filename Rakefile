require 'bundler/gem_tasks'
require 'rake/clean'
require 'fileutils'

CLEAN.include %w[**/.DS_Store tmp *.log doc website/doc]

  #~ p.clean_globs |= %w[**/.DS_Store tmp *.log]
  #~ path = (p.rubyforge_name == p.name) ? p.rubyforge_name : "\#{p.rubyforge_name}/\#{p.name}"
  #~ p.remote_rdoc_dir = File.join(path.gsub(/^#{p.rubyforge_name}\/?/,''), 'rdoc')
  #~ p.rsync_args = '-av --delete --ignore-errors'
#~ end

Dir['tasks/**/*.rake'].each { |t| load t }
