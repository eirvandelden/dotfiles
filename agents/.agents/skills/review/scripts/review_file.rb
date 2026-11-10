# What the review.md of a change says: whether it has a round, and which findings are still open.
# A finding is closed only when the text after its last arrow is "fixed (<commit subject>)" or
# "dismissed: <reason>"; anything else, empty included, leaves it open.
class Review
  FINDING = /\A\s*- \[ \] (Important|Nit):/
  ROUND = /^## Round /
  ROUND_COMMIT = /^## Round .* — ([0-9a-f]+)(?: \([a-z]+\))?\s*$/
  FIRST_FINDING = /^\s*- \[ \] (?:Important|Nit): (.+?) — `/
  SUBJECT_LIMIT = 72
  CLOSED_SLOT = /\A\s*(fixed \(\s*[^)\s][^)]*\)|dismissed:\s*\S.*)\s*\z/

  #: (String text) -> void
  def initialize(text)
    @text = text
  end

  #: -> bool
  def rounds?
    @text.match?(ROUND)
  end

  #: -> Array[String]
  def open_findings
    @text.lines.map(&:strip).select { |line| line.match?(FINDING) && !closed?(line) }
  end

  # The short SHA at the end of the last "## Round" heading, before any "(claude)" or "(codex)"; nil when none.
  #: -> String?
  def reviewed_commit
    @text.scan(ROUND_COMMIT).flatten.last
  end

  # "docs: review findings for <first finding>", cut at a word boundary so the subject stays at most 72 characters.
  # A file with no finding answers "docs: review with no findings for <slug>".
  #: (String slug) -> String
  def commit_subject(slug)
    finding = @text[FIRST_FINDING, 1]
    return "docs: review with no findings for #{slug}" if finding.nil?

    prefix = "docs: review findings for "
    "#{prefix}#{cut(finding, SUBJECT_LIMIT - prefix.length)}"
  end

  private

  def cut(text, limit)
    return text if text.length <= limit

    text[0, limit + 1].rpartition(" ").first.then { |words| words.empty? ? text[0, limit] : words }
  end

  def closed?(line)
    line.include?("→") && line.split("→", -1).last.match?(CLOSED_SLOT)
  end
end
