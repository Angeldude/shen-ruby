#!/usr/bin/env ruby
$LOAD_PATH << File.expand_path('../../lib', __FILE__)
require 'shen_ruby'

# Load the Shen Envinronment
puts "Loading Shen. This takes a while...."
start = Time.now.to_f
env = ShenRuby::Environment.new
now = Time.now.to_f
puts "Loaded in %0.2f seconds.\n" % (now - start)

# Launch the REPL
command = :"shen-shen"
begin
  env.__eval(Kl::Cons.list([command]))
rescue StandardError => e
  # K Lambda simple errors are already handled by the Shen REPL. Therefore
  # this must be another type of exception. Print it as such and reenter
  # the REPL without re-display the initial credits.
  puts "Ruby exception: #{e.message}"
  command = :"shen-loop"
  retry
end
