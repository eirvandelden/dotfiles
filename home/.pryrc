def pbcopy(input)
  command = system('which pbcopy > /dev/null 2>&1') ? 'pbcopy' : 'xsel -ib'

  input.tap do
    system("echo '#{input}' | #{command}")
  end
end

Pry::Commands.block_command "copy", "Copy to clipboard" do |thing_to_copy|
  copy(eval(thing_to_copy))
end
