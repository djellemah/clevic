file 'ui/browser_ui.rb' => ['ui/browser.ui'] do |t|
  #~ puts "t.source: #{t.source.inspect}"
  #~ puts "t.sources: #{t.sources.inspect}"
  #~ puts "t.name: #{t.name.inspect}"
  #~ puts "t.prerequisites: #{t.prerequisites.inspect}"
  sh "rbuic4 #{t.prerequisites} -o #{t.name}"
end

task :default => 'ui/browser_ui.rb'
