# The shared playbook every agent imports as PLAYBOOK.md. Tests read it here, so a move touches one line.
module Playbook
  PATH = "agents/.agents/PLAYBOOK.md" #: String

  #: () -> String
  def self.text
    @text ||= File.read(File.expand_path("../#{PATH}", __dir__))
  end
end
