# remove hoe documentation task
Rake::Task['docs'].clear

# make this respond to docs, so it fits in with the rest of the build
Rake::RDocTask.new do |rdoc|
  rdoc.name = :docs
  rdoc.title = "Clevic DB UI builder"
  rdoc.main = 'README.txt'
  rdoc.rdoc_dir = 'doc'
  rdoc.rdoc_files.include %w{History.txt lib/**/*.rb README.txt TODO}
  rdoc.options += [ '-SHN' ]
end
