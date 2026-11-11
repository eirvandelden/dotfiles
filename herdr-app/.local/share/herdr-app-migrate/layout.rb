require_relative "command_line"

module HerdrAppMigration
  Split = Data.define(
    :from,      #: String
    :to,        #: String
    :direction  #: String
  )

  # Turns one tab's pane rectangles into split steps by guillotine cuts. Ratios are not kept.
  class Layout
    #: (Array[[String, Hash[String, Integer]]] rects, ?label: String) -> void
    def initialize(rects, label: "")
      @label = label
      @rects = rects.to_h { |id, rect| [ id, rect&.transform_keys(&:to_sym) ] }
      raise Refusal, "tab #{label}: a pane has no rectangle" if @rects.value?(nil)
      raise Refusal, "tab #{label}: panes overlap" if overlapping?
    end

    # The pane the tab's first terminal stands for: the top-left one by geometry.
    #: -> String
    def anchor
      anchor_of(@rects.keys)
    end

    #: -> Array[Split]
    def steps
      cut(@rects.keys)
    end

    private

    def cut(ids)
      return [] if ids.one?

      direction, first, second = halves(ids)
      [ Split.new(anchor_of(ids), anchor_of(second), direction), *cut(first), *cut(second) ]
    end

    def halves(ids)
      [ [ "right", :x, :width ], [ "down", :y, :height ] ].each do |direction, start, size|
        edges = ids.map { |id| @rects[id][start] + @rects[id][size] }.sort.uniq
        edges.each do |edge|
          first, second = ids.partition { |id| @rects[id][start] + @rects[id][size] <= edge }
          return [ direction, first, second ] if clean?(first, second, start, edge)
        end
      end
      raise Refusal, "tab #{@label}: the panes have no clean cut"
    end

    def clean?(first, second, start, edge)
      first.any? && second.any? && second.all? { |id| @rects[id][start] >= edge }
    end

    def anchor_of(ids)
      ids.min_by { |id| [ @rects[id][:y], @rects[id][:x] ] }
    end

    def overlapping?
      @rects.values.combination(2).any? { |one, other| overlap?(one, other, :x, :width) && overlap?(one, other, :y, :height) }
    end

    def overlap?(one, other, start, size)
      one[start] < other[start] + other[size] && other[start] < one[start] + one[size]
    end
  end
end
