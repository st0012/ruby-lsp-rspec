# typed: strict
# frozen_string_literal: true

require "ruby_lsp/addon"
require "ruby_lsp/internal"

require_relative "code_lens"
require_relative "document_symbol"

module RubyLsp
  module RSpec
    class Addon < ::RubyLsp::Addon
      extend T::Sig

      sig { override.params(global_state: GlobalState, message_queue: Thread::Queue).void }
      def activate(global_state, message_queue); end

      sig { override.void }
      def deactivate; end

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

        CodeLens.new(response_builder, uri, dispatcher)
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

      sig { override.returns(String) }
      def name
        "Ruby LSP RSpec"
      end
    end
  end
end
