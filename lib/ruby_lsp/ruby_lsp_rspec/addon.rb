# typed: strict
# frozen_string_literal: true

require "ruby_lsp/addon"
require "ruby_lsp/internal"

require_relative "code_lens"

module RubyLsp
  module RSpec
    class Addon < ::RubyLsp::Addon
      extend T::Sig

      sig { override.void }
      def activate; end

      sig { override.void }
      def deactivate; end

      # Creates a new CodeLens listener. This method is invoked on every CodeLens request
      sig do
        override.params(
          uri: URI::Generic,
          emitter: EventEmitter,
          message_queue: Thread::Queue,
        ).returns(T.nilable(Listener[T::Array[Interface::CodeLens]]))
      end
      def create_code_lens_listener(uri, emitter, message_queue)
        CodeLens.new(uri, emitter, message_queue)
      end

      sig { override.returns(String) }
      def name
        "Ruby LSP RSpec"
      end
    end
  end
end
