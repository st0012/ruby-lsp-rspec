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
      extend T::Sig

      sig { returns(T::Boolean) }
      attr_reader :debug

      sig { void }
      def initialize
        super
        @debug = T.let(false, T::Boolean)
        @rspec_command = T.let(nil, T.nilable(String))
      end

      sig { override.params(global_state: GlobalState, message_queue: Thread::Queue).void }
      def activate(global_state, message_queue)
        @index = T.let(global_state.index, T.nilable(RubyIndexer::Index))

        settings = global_state.settings_for_addon(name)
        @rspec_command = rspec_command(settings)
        @debug = settings&.dig(:debug) || false
      end

      sig { override.void }
      def deactivate; end

      sig { override.returns(String) }
      def name
        "ruby-lsp-rspec"
      end

      sig { override.returns(String) }
      def version
        VERSION
      end

      # Creates a new CodeLens listener. This method is invoked on every CodeLens request
      sig do
        override.params(
          response_builder: ResponseBuilders::CollectionResponseBuilder[Interface::CodeLens],
          uri: URI::Generic,
          dispatcher: Prism::Dispatcher,
        ).void
      end
      def create_code_lens_listener(response_builder, uri, dispatcher)
        return unless uri.to_standardized_path&.end_with?("_test.rb") || uri.to_standardized_path&.end_with?("_spec.rb")

        CodeLens.new(response_builder, uri, dispatcher, T.must(@rspec_command), debug: debug)
      end

      # Creates a new Discover Tests listener. This method is invoked on every DiscoverTests request
      sig do
        override.params(
          response_builder: ResponseBuilders::TestCollection,
          dispatcher: Prism::Dispatcher,
          uri: URI::Generic,
        ).void
      end
      def create_discover_tests_listener(response_builder, dispatcher, uri)
        return unless uri.to_standardized_path&.end_with?("_spec.rb")

        TestDiscovery.new(response_builder, dispatcher, uri)
      end

      # Resolves the minimal set of commands required to execute the requested tests
      sig do
        override.params(
          items: T::Array[T::Hash[Symbol, T.untyped]],
        ).returns(T::Array[String])
      end
      def resolve_test_commands(items)
        commands = []

        # Group test items by file path
        items_by_file = Hash.new { |h, k| h[k] = [] }
        full_files = []

        # Process the queue
        queue = items.dup
        until queue.empty?
          item = T.must(queue.shift)
          path = item[:source_file]
          next if path.nil?

          children = item[:children] || []
          tags = item[:tags] || []

          if tags.include?("test_case")
            # This is a specific test, add it to its file's list
            items_by_file[path] << item
          elsif tags.include?("test_group") || tags.include?("test_class")
            if children.empty?
              # If no children, we need to run the entire group/file
              full_files << path
            else
              # Otherwise process children
              queue.concat(children)
            end
          elsif tags.include?("test_file")
            full_files << path if children.empty?
          end
        end

        # Build commands for individual tests or entire files
        base_cmd = T.must(@rspec_command)

        # Add commands for specific tests
        items_by_file.each do |file_path, file_items|
          file_items.each do |item|
            line_number = item[:range][:start][:line]
            commands << "#{base_cmd} #{file_path}:#{line_number + 1}"
          end
        end

        # Add commands for entire files
        full_files.each do |file_path|
          commands << "#{base_cmd} #{file_path}"
        end

        commands.uniq
      end

      sig do
        override.params(
          response_builder: ResponseBuilders::DocumentSymbol,
          dispatcher: Prism::Dispatcher,
        ).void
      end
      def create_document_symbol_listener(response_builder, dispatcher)
        DocumentSymbol.new(response_builder, dispatcher)
      end

      sig do
        override.params(
          response_builder: ResponseBuilders::CollectionResponseBuilder[T.any(Interface::Location, Interface::LocationLink)],
          uri: URI::Generic,
          node_context: NodeContext,
          dispatcher: Prism::Dispatcher,
        ).void
      end
      def create_definition_listener(response_builder, uri, node_context, dispatcher)
        return unless uri.to_standardized_path&.end_with?("_test.rb") || uri.to_standardized_path&.end_with?("_spec.rb")

        Definition.new(response_builder, uri, node_context, T.must(@index), dispatcher)
      end

      private

      sig { params(settings: T.nilable(T::Hash[Symbol, T.untyped])).returns(String) }
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
