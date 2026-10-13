# Summarises docs/changes/<slug>/review.md for the handover: per round its
# number, source, reviewed revision, finding counts and how each finding closed.
# Round shape: `## Round <n> — <UTC> — <short SHA>` plus an optional ` (codex)`
# or ` (claude)`; findings `- [ ] Important: <text> — `<file>:<line>` → <closure>`.
class ReviewSummary
  ROUND = /\A## Round (\d+) — \S+ — (\h+)(?: \((codex|claude)\))?\s*\z/
  FINDING = /\A- \[([ xX])\] (\w+): (.*)\z/
  CLOSURE = /\s→\s(fixed\b.*|dismissed\b.*)\z/
  EXCERPT_LIMIT = 140

  def initialize(markdown)
    @markdown = markdown
  end

  def to_markdown
    rounds = parse
    return "No review rounds recorded." if rounds.empty?

    rounds.map { |round| render(round) }.join("\n")
  end

  private

  def parse
    rounds = []
    @markdown.each_line(chomp: true) do |line|
      if (match = line.match(ROUND))
        rounds << { number: match[1], sha: match[2], source: match[3] || "claude", findings: [], prose: +"" }
      elsif rounds.any? && (finding = parse_finding(line))
        rounds.last[:findings] << finding
      elsif rounds.any?
        rounds.last[:prose] << line
      end
    end
    rounds
  end

  def parse_finding(line)
    match = line.match(FINDING) or return nil
    text = match[3]
    closure = text[CLOSURE, 1]
    { severity: match[2], checked: match[1] != " ", excerpt: excerpt(text.sub(CLOSURE, "")), closure: closure }
  end

  def excerpt(text)
    body = text.sub(/\s+—\s+`[^`]+`\s*\z/, "").strip
    sentence = body[/\A.*?[.!?](?=\s|\z)/m] || body
    sentence.length > EXCERPT_LIMIT ? "#{sentence[0, EXCERPT_LIMIT - 1]}…" : sentence
  end

  def render(round)
    head = "- Round #{round[:number]} (#{round[:source]}), reviewed #{round[:sha]}: #{counts(round)}."
    ([ head ] + round[:findings].map { |finding| "  - #{finding[:severity]}: #{finding[:excerpt]} — #{closure(finding)}" }).join("\n")
  end

  def counts(round)
    return clean_round(round[:prose]) if round[:findings].empty?

    round[:findings].map { |finding| finding[:severity] }.tally.map { |severity, count| "#{count} #{severity}" }.join(", ")
  end

  def clean_round(prose)
    prose.match?(/\bno (?:actionable )?(?:findings|defects|issues)\b/i) ? "no findings" : "no itemised findings"
  end

  def closure(finding)
    closure = finding[:closure]
    return finding[:checked] ? "closed (no closure recorded)" : "open" unless closure
    return closure unless closure.start_with?("dismissed")

    %(dismissed: "#{closure.sub(/\Adismissed:?\s*/, '').strip}")
  end
end
