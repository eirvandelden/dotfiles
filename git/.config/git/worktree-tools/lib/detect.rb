#!/usr/bin/env rv run ruby

require_relative 'common'

module WorktreeTools
  class ProjectDetector
    include Helpers

    attr_reader :path #: Pathname
    attr_reader :project_type #: Symbol?
    attr_reader :project_info #: Hash[Symbol, untyped]

    #: (?(String | Pathname) path) -> void
    def initialize(path = '.')
      @path = Pathname.new(File.expand_path(path))
      @project_type = nil
      @project_info = {}
    end

    #: -> self
    def detect!
      @project_type = detect_project_type
      @project_info = detect_project_info
      self
    end

    #: -> bool
    def rails?
      @project_type == :rails
    end

    #: -> bool
    def node?
      @project_type == :node
    end

    #: -> bool
    def generic?
      @project_type == :generic
    end

    #: -> bool
    def puma_dev_compatible?
      return false unless rails?

      # Check for config.ru or config/application.rb
      File.exist?(@path.join('config.ru')) ||
        File.exist?(@path.join('config', 'application.rb'))
    end

    #: -> Hash[Symbol, untyped]?
    def conductor_info
      return nil unless in_conductor?

      {
        root: conductor_root,
        workspace_path: conductor_workspace_path,
        workspace_name: conductor_workspace_name,
        port: conductor_port
      }
    end

    private

    def detect_project_type
      # Rails: Gemfile + config/application.rb
      if File.exist?(@path.join('Gemfile')) &&
         File.exist?(@path.join('config', 'application.rb'))
        return :rails
      end

      # Node: package.json
      if File.exist?(@path.join('package.json'))
        return :node
      end

      # Default to generic
      :generic
    end

    def detect_project_info
      info = {
        name: worktree_name(@path),
        root: git_root(@path),
        is_main_worktree: main_worktree?(@path)
      }

      if in_conductor?
        info[:conductor] = conductor_info
      end

      info
    end
  end
end
