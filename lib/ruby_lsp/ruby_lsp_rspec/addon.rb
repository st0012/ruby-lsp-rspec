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
        queue = items.dup

        full_files = []

        until queue.empty?
          item = T.must(queue.shift)
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
            commands << "#{@rspec_command} #{path}:#{start_line + 1}"
          else
            full_files << "#{path}:#{item.dig(:range, :start, :line) + 1}"
          end

          queue.concat(children)
        end

        unless full_files.empty?
          commands << "#{@rspec_command} #{full_files.join(" ")}"
        end

        commands
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
