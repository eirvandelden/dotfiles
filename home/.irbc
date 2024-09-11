# source: https://pawelurbanek.com/rails-console-aliases
# After a while you can use my gem to analyze a local IRB sessions history:
# ```
# gem install lazyme
# lazyme ~/.irb-history
# ```
# require 'irb/ext/save-history'

IRB.conf[:SAVE_HISTORY]     = 10000
IRB.conf[:HISTORY_FILE]     = "#{ENV['HOME']}/.irb-history"
IRB.conf[:RUBY_YJIT_ENABLE] = 1

## Readable autocomplete
if defined? Reline::Face
  Reline::Face.config(:completion_dialog) do |conf|
    conf.define(:default, foreground: "#cad3f5", background: "#363a4f")
    conf.define(:enhanced, foreground: "#cad3f5", background: "#5b6078")
    conf.define(:scrollbar, foreground: "#c6a0f6", background: "#181926")
  end
else
  IRB.conf[:USE_AUTOCOMPLETE] = false
end

# Custom aliases
def cp(string)
  `echo "#{string}" | pbcopy`
  puts "copied in clipboard"
end

def me
  @me ||= User.find_by(email: `git config user.email`.strip)
end
