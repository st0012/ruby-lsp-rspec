# typed: strict
# frozen_string_literal: true

require "ruby_lsp/addon"
require "ruby_lsp/internal"

require_relative "code_lens"
require_relative "document_symbol"
require_relative "definition"
require_relative "indexing_enhancement"

module RubyLsp
  module RSpec
    class Addon < ::RubyLsp::Addon
      extend T::Sig

      sig { returns(T.nilable(String)) }
      attr_reader :rspec_command

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
        @rspec_command = T.let(settings&.dig(:rspecCommand), T.nilable(String))
        @debug = settings&.dig(:debug) || false
      end

      sig { override.void }
      def deactivate; end

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

        CodeLens.new(response_builder, uri, dispatcher, rspec_command: rspec_command, debug: debug)
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
          response_builder: ResponseBuilders::CollectionResponseBuilder[T.any(
            Interface::Location,
            Interface::LocationLink,
          )],
          uri: URI::Generic,
          node_context: NodeContext,
          dispatcher: Prism::Dispatcher,
        ).void
      end
      def create_definition_listener(response_builder, uri, node_context, dispatcher)
        return unless uri.to_standardized_path&.end_with?("_test.rb") || uri.to_standardized_path&.end_with?("_spec.rb")

        Definition.new(response_builder, uri, node_context, T.must(@index), dispatcher)
      end

      sig { override.returns(String) }
      def name
        "Ruby LSP RSpec"
      end
    end
  end
end
