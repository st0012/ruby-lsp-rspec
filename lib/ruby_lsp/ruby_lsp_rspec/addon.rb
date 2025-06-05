# typed: strict
# frozen_string_literal: true

require "ruby_lsp/addon"
require "ruby_lsp/internal"

require_relative "code_lens"
require_relative "document_symbol"
require_relative "definition"
require_relative "indexing_enhancement"
require_relative "test_discovery"
require_relative "spec_style_patch"

module RubyLsp
  module RSpec
    class Addon < ::RubyLsp::Addon
      FORMATTER_PATH = File.expand_path("rspec_formatter.rb", __dir__) #: String
      FORMATTER_NAME = "RubyLsp::RSpec::RSpecFormatter" #: String

      #: bool
      attr_reader :debug

      #: -> void
      def initialize
        super
        @debug = false #: bool
        @rspec_command = nil #: String?
      end

      # @override
      #: (GlobalState, Thread::Queue) -> void
      def activate(global_state, message_queue)
        @index = global_state.index #: RubyIndexer::Index?
        @global_state = global_state #: GlobalState?

        settings = global_state.settings_for_addon(name)
        @rspec_command = rspec_command(settings)
        @workspace_path = global_state.workspace_path #: String?
        @debug = settings&.dig(:debug) || false
      end

      # @override
      #: -> void
      def deactivate; end

      # @override
      #: -> String
      def name
        "Ruby LSP RSpec"
      end

      # @override
      #: -> String
      def version
        VERSION
      end

      # Creates a new CodeLens listener. This method is invoked on every CodeLens request
      # @override
      #: (ResponseBuilders::CollectionResponseBuilder[Interface::CodeLens], URI::Generic, Prism::Dispatcher) -> void
      def create_code_lens_listener(response_builder, uri, dispatcher)
        return unless uri.to_standardized_path&.end_with?("_test.rb") || uri.to_standardized_path&.end_with?("_spec.rb")
        return if @global_state&.enabled_feature?(:fullTestDiscovery)

        CodeLens.new(
          response_builder,
          uri,
          dispatcher,
          @rspec_command, #: as !nil
          debug: debug,
        )
      end

      # Creates a new Discover Tests listener. This method is invoked on every DiscoverTests request
      # @override
      #: (ResponseBuilders::TestCollection, Prism::Dispatcher, URI::Generic) -> void
      def create_discover_tests_listener(response_builder, dispatcher, uri)
        return unless uri.to_standardized_path&.end_with?("_spec.rb")

        TestDiscovery.new(
          response_builder,
          dispatcher,
          uri,
          @workspace_path, #: as !nil
        )
      end

      # Resolves the minimal set of commands required to execute the requested tests
      # @override
      #: (Array[Hash[Symbol, untyped]]) -> Array[String]
      def resolve_test_commands(items)
        commands = []
        queue = items.dup

        full_files = []

        until queue.empty?
          item = queue.shift #: as !nil
          tags = Set.new(item[:tags])
          next unless tags.include?("framework:rspec")

          children = item[:children]
          uri = URI(item[:uri])
          path = uri.full_path
          next unless path

          if tags.include?("test_dir")
            if children.empty?
              full_files.concat(Dir.glob(
                "#{path}/**/*_spec.rb",
                File::Constants::FNM_EXTGLOB | File::Constants::FNM_PATHNAME,
              ))
            end
          elsif tags.include?("test_file")
            full_files << path if children.empty?
          elsif tags.include?("test_group")
            start_line = item.dig(:range, :start, :line)
            commands << "#{@rspec_command} -r #{FORMATTER_PATH} -f #{FORMATTER_NAME} #{path}:#{start_line + 1}"
          else
            full_files << "#{path}:#{item.dig(:range, :start, :line) + 1}"
          end

          queue.concat(children)
        end

        unless full_files.empty?
          commands << "#{@rspec_command} -r #{FORMATTER_PATH} -f #{FORMATTER_NAME} #{full_files.join(" ")}"
        end

        commands
      end

      # @override
      #: (ResponseBuilders::DocumentSymbol, Prism::Dispatcher) -> void
      def create_document_symbol_listener(response_builder, dispatcher)
        DocumentSymbol.new(response_builder, dispatcher)
      end

      # @override
      #: (ResponseBuilders::CollectionResponseBuilder[Interface::Location | Interface::LocationLink], URI::Generic, NodeContext, Prism::Dispatcher) -> void
      def create_definition_listener(response_builder, uri, node_context, dispatcher)
        return unless uri.to_standardized_path&.end_with?("_test.rb") || uri.to_standardized_path&.end_with?("_spec.rb")

        Definition.new(
          response_builder,
          uri,
          node_context,
          @index, #: as !nil
          dispatcher,
        )
      end

      private

      #: (Hash[Symbol, untyped]?) -> String
      def rspec_command(settings)
        @rspec_command ||= settings&.dig(:rspecCommand) || begin
          cmd = if File.exist?(File.join(Dir.pwd, "bin", "rspec"))
            "bin/rspec"
          else
            "rspec"
          end

          begin
            Bundler.with_original_env { Bundler.default_lockfile }
            "bundle exec #{cmd}"
          rescue Bundler::GemfileNotFound
            cmd
          end
        end
      end
    end
  end
end
