# Reads the "## Critique" section of an autonomous plan.md. Shared by commit-plan and
# start-delivery, so both agree on when a critique is closed.
#
# The critique is the last thing in the file and runs to its end, so a second "## Critique", a later
# section or a footer after it is a line the allow-list below refuses, never a blind spot. Every
# round holds "No findings." alone, or findings written "- <finding> → fixed (<subject>)" or
# "- <finding> → dismissed: <reason>", each optionally explained by indented items.
module PlanCritique
  # The slot is the text after a finding's last arrow; anything earlier is the finding itself.
  CLOSED_SLOT = /\A\s*(fixed \(\s*[^)\s][^)]*\)|dismissed:\s*\S.*)\s*\z/
  ROUND = /^### Round\b/
  FINDING = /^[-*] +[^\s→]/
  EXPLANATION = /^\s+(?:[-*+]|\d+[.)])\s/
  NO_FINDINGS = /^No findings\.\s*$/

  module_function

  #: (String text) -> bool
  def closed?(text)
    problems(text).empty?
  end

  # The reasons the critique is not closed; empty when it is.
  #: (String text) -> Array[String]
  def problems(text)
    critique = section(text)
    return [ "no Critique section" ] unless critique
    return [ "the Critique section has no Round heading" ] unless critique.match?(ROUND)

    open = rounds(critique).flat_map { |group| round_problems(group) }
    open.empty? ? [] : [ "open critique findings remain: #{open.join.strip}" ]
  end

  #: (String text) -> String?
  def section(text)
    text[/^## Critique\s*$.*\z/m]
  end

  #: (String line) -> bool
  def closed_line?(line)
    line.include?("→") && line.split("→", -1).last.match?(CLOSED_SLOT)
  end

  # The non-blank lines after the "## Critique" heading, one group per round. A group that does
  # not start with a Round heading is text before the first round.
  #: (String critique) -> Array[Array[String]]
  def rounds(critique)
    critique.lines.drop(1).reject { |line| line.strip.empty? }.slice_before { |line| line.match?(ROUND) }
  end

  #: (Array[String] group) -> Array[String]
  def round_problems(group)
    return group unless group.first.match?(ROUND)

    entries = group.drop(1)
    return [ "#{group.first.strip} has no finding and no \"No findings.\" line\n" ] if entries.empty?
    return [] if entries.one? && entries.first.match?(NO_FINDINGS)

    unreadable_entries(entries)
  end

  # An allow-list, so any shape this module does not know fails closed: a closed top-level finding,
  # or an indented item explaining the closed finding above it. Anything else is reported.
  #: (Array[String] entries) -> Array[String]
  def unreadable_entries(entries)
    parent_closed = false
    entries.reject do |line|
      parent_closed = closed_line?(line) if line.match?(FINDING)
      parent_closed && (line.match?(FINDING) || line.match?(EXPLANATION))
    end
  end
end
