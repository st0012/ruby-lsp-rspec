# typed: strict
# frozen_string_literal: true

module RubyLsp
  module RSpec
    class TestDiscovery
      extend T::Sig

      include ::RubyLsp::Requests::Support::Common

      sig do
        params(
          response_builder: ::RubyLsp::ResponseBuilders::TestCollection,
          dispatcher: Prism::Dispatcher,
          uri: URI::Generic,
        ).void
      end
      def initialize(response_builder, dispatcher, uri)
        @response_builder = response_builder
        @dispatcher = dispatcher
        @uri = uri
        @path = T.let(T.must(uri.to_standardized_path), String)
        @group_stack = T.let([], T::Array[::RubyLsp::Requests::Support::TestItem])
        @anonymous_example_count = T.let(0, Integer)

        dispatcher.register(
          self,
          :on_call_node_enter,
          :on_call_node_leave,
        )
      end

      sig { params(node: Prism::CallNode).void }
      def on_call_node_enter(node)
        return unless ["describe", "context", "it", "specify", "example"].include?(node.message)

        case node.message
        when "describe", "context"
          handle_describe(node)
        when "it", "specify", "example"
          handle_example(node)
        end
      end

      sig { params(node: Prism::CallNode).void }
      def on_call_node_leave(node)
        case node.message
        when "context", "describe"
          return unless valid_group?(node)

          @group_stack.pop
        end
      end

      private

      sig { params(node: Prism::CallNode).returns(T.nilable(String)) }
      def extract_description(node)
        # Try to extract the description from a string literal argument
        first_arg = node.arguments&.arguments&.first
        return "(anonymous example #{@anonymous_example_count += 1})" if first_arg.nil?

        if first_arg.is_a?(Prism::StringNode)
          return first_arg.content
        elsif first_arg.is_a?(Prism::SymbolNode)
          return first_arg.value
        end

        nil
      end

      sig { params(node: Prism::CallNode).void }
      def handle_describe(node)
        description = extract_description(node)
        return if description.nil?

        parent = find_parent_test_group
        test_item = ::RubyLsp::Requests::Support::TestItem.new(
          "#{parent&.id || ""}::#{description}",
          description,
          @uri,
          range_from_node(node),
          framework: :rspec,
        )

        if parent
          parent.add(test_item)
        else
          @response_builder.add(test_item)
        end

        @group_stack.push(test_item)
      end

      sig { params(node: Prism::CallNode).void }
      def handle_example(node)
        description = extract_description(node)
        parent = find_parent_test_group
        return unless parent

        test_item = ::RubyLsp::Requests::Support::TestItem.new(
          "#{parent.id}::#{description}",
          description,
          @uri,
          range_from_node(node),
          framework: :rspec,
        )

        parent.add(test_item)
      end

      sig { returns(T.nilable(::RubyLsp::Requests::Support::TestItem)) }
      def find_parent_test_group
        @group_stack.last
      end

      sig { params(node: Prism::CallNode).returns(T::Boolean) }
      def valid_group?(node)
        !(node.block.nil? || (node.receiver && node.receiver&.slice != "RSpec"))
      end
    end
  end
end
