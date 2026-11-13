require_relative "agent_record"

module HerdrAppAgents
  # The last shutdown of one core, as its agent records show it.
  class Shutdown
    WINDOW = 600 # seconds

    #: (Array[AgentRecord] records, started_at: Time) -> void
    def initialize(records, started_at:)
      @records = records
      @started_at = started_at
    end

    # The newest transcript write before started_at; nil when there is none.
    #: -> Time?
    def moment
      @records.filter_map(&:transcript_written_at).select { |written| written < @started_at }.max
    end

    # Records with a transcript written in [moment - WINDOW, started_at) and not touched_since?(started_at).
    #: -> Array[AgentRecord]
    def running
      shutdown = moment
      return [] unless shutdown

      @records.select { |record| in_window?(record, shutdown) && !record.touched_since?(@started_at) }
    end

    private

    #: (AgentRecord record, Time shutdown) -> bool
    def in_window?(record, shutdown)
      written = record.transcript_written_at
      !written.nil? && written >= shutdown - WINDOW && written < @started_at
    end
  end
end
