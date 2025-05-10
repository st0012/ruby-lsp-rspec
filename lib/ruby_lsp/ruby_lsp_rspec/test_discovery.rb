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
          workspace_path: String,
        ).void
      end
      def initialize(response_builder, dispatcher, uri, workspace_path)
        @response_builder = response_builder
        @dispatcher = dispatcher
        @uri = uri
        @path = T.let(T.must(uri.to_standardized_path), String)
        @workspace_path = T.let(workspace_path, String)
        @group_stack = T.let([], T::Array[::RubyLsp::Requests::Support::TestItem])

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
        return "example at #{relative_location(node)}" if first_arg.nil?

        case first_arg
        when Prism::StringNode
          first_arg.content
        when Prism::SymbolNode
          first_arg.value
        when Prism::ConstantReadNode
          first_arg.name.to_s
        when Prism::ConstantPathNode
          first_arg.full_name
        end
      end

      sig { params(node: Prism::CallNode).void }
      def handle_describe(node)
        description = extract_description(node)
        return if description.nil?

        parent = find_parent_test_group
        parent_id = parent ? "#{parent.id}::" : ""

        test_item = ::RubyLsp::Requests::Support::TestItem.new(
          "#{parent_id}#{relative_location(node)}",
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
          "#{parent.id}::#{relative_location(node)}",
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

      sig { params(node: Prism::CallNode).returns(String) }
      def relative_location(node)
        uri_path = T.must(@uri.to_standardized_path)
        relative_path = Pathname.new(uri_path).relative_path_from(Pathname.new(@workspace_path))
        "./#{relative_path}:#{node.location.start_line}"
      end
    end
  end
end
