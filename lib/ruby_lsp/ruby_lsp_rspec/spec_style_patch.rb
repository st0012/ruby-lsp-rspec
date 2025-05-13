# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Listeners
    # Patching this listener so it doesn't generate test items for RSpec tests
    class SpecStyle
      #: (ResponseBuilders::TestCollection, GlobalState, Prism::Dispatcher, URI::Generic) -> void
      def initialize(response_builder, global_state, dispatcher, uri)
        super
      end
    end
  end
end
