# typed: strict
# frozen_string_literal: true

module RubyLsp
  module Listeners
    # Patching this listener so it doesn't generate test items for RSpec tests
    class SpecStyle
      extend T::Sig

      sig { params(response_builder: ResponseBuilders::TestCollection, global_state: GlobalState, dispatcher: Prism::Dispatcher, uri: URI::Generic).void }
      def initialize(response_builder, global_state, dispatcher, uri)
        super
      end
    end
  end
end
