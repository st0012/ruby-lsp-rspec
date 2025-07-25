# typed: strict
# frozen_string_literal: true

module RubyIndexer
  class Enhancement
    # If we change ruby-lsp to use a `T.let` then this can be removed
    def initialize(listener)
      @listener = listener #: DeclarationListener
    end
  end
end
