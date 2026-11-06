# Loaded by deliver, which defines Shell and Refusal first.
# Closes the stage blocks this change opened, once they are idle or done. hand-off-plan.sh and
# start-review.sh list each one as a bare block id in <git-common-dir>/rex/stage-panes-<slug>.
# Block ids never repeat, so a listed id is the block it was. A block closes only while `rex block ls`
# still lists it and its program_status state is idle or done, and never when it is the calling block
# or the intent block the intent skill recorded. Best effort, like the gh-dash block: the PR exists by
# now, so a Rex failure only warns.
class RexPanes
  include Shell

  CLOSABLE = %w[idle done].freeze

  #: (String slug, String common_dir) -> void
  def initialize(slug, common_dir)
    @record = File.join(common_dir, "rex", "stage-panes-#{slug}")
    @intent_record = File.join(common_dir, "rex", "intent-pane-#{slug}")
    @session = ENV.fetch("REX_SESSION", "")
  end

  #: -> void
  def close_stale
    return unless !@session.empty? && File.exist?(@record)

    stale.each { |block_id| system("rex", "block", "close", "-s", @session, block_id) }
    File.delete(@record)
  rescue Refusal, JSON::ParserError => error
    warn("The stage blocks stay open: #{error.message}")
  end

  private

  def stale
    listed.select { |block_id| recorded.include?(block_id) && closable?(block_id) }
  end

  def closable?(block_id)
    !kept.include?(block_id) && idle_or_done?(states_of(block_id))
  end

  def idle_or_done?(states)
    states.any? && states.all? { |state| CLOSABLE.include?(state) }
  end

  def recorded
    @recorded ||= File.readlines(@record, chomp: true).map(&:strip).reject(&:empty?)
  end

  def kept
    intent = File.exist?(@intent_record) ? File.readlines(@intent_record, chomp: true).first : nil
    [ ENV["REX_BLOCK"], intent ].compact
  end

  def listed
    JSON.parse(capture("rex", "block", "ls", "-s", @session, "--json")).fetch("blocks", []).map { |block| block["block_id"] }
  end

  # The state of every program record. A block with none, a plain shell, or an unreadable answer stays open.
  def states_of(block_id)
    request = JSON.generate("block_id" => block_id, "method" => "program_status")
    answer = JSON.parse(capture("rex", "api", "call", "-s", @session, "block.method", request))
    records = answer["records"]
    records.is_a?(Array) ? records.map { |record| record.is_a?(Hash) ? record["state"] : nil } : []
  rescue JSON::ParserError
    []
  end
end
