# What the review.md of a change says: whether it has a round, and which findings are still open.
# A finding is closed only when the text after its last arrow is "fixed (<commit subject>)" or
# "dismissed: <reason>"; anything else, empty included, leaves it open.
class Review
  FINDING = /\A\s*- \[ \] (Important|Nit):/
  ROUND = /^## Round /
  CLOSED_SLOT = /\A\s*(fixed \(\s*[^)\s][^)]*\)|dismissed:\s*\S.*)\s*\z/

  def initialize(text)
    @text = text
  end

  def rounds?
    @text.match?(ROUND)
  end

  def open_findings
    @text.lines.map(&:strip).select { |line| line.match?(FINDING) && !closed?(line) }
  end

  private

  def closed?(line)
    line.include?("→") && line.split("→", -1).last.match?(CLOSED_SLOT)
  end
end
