# typed: strict
# frozen_string_literal: true

module RubyLsp
  module RSpec
    class TestDiscovery
      include ::RubyLsp::Requests::Support::Common

      #: (ResponseBuilders::TestCollection, Prism::Dispatcher, URI::Generic, String) -> void
      def initialize(response_builder, dispatcher, uri, workspace_path)
        @response_builder = response_builder
        @dispatcher = dispatcher
        @uri = uri

        path = uri.to_standardized_path #: as !nil
        @path = path #: String
        @workspace_path = workspace_path #: String
        @group_stack = [] #: Array[::RubyLsp::Requests::Support::TestItem]

        dispatcher.register(
          self,
          :on_call_node_enter,
          :on_call_node_leave,
        )
      end

      #: (Prism::CallNode) -> void
      def on_call_node_enter(node)
        return unless ["describe", "context", "it", "specify", "example", "feature", "scenario"].include?(node.message)

        case node.message
        when "describe", "context", "feature"
          return unless valid_group?(node)
          handle_describe(node)
        when "it", "specify", "example", "scenario"
          handle_example(node)
        end
      end

      #: (Prism::CallNode) -> void
      def on_call_node_leave(node)
        case node.message
        when "context", "describe", "feature"
          return unless valid_group?(node)

          @group_stack.pop
        end
      end

      private

      #: (Prism::CallNode) -> String
      def extract_description(node)
        # Try to extract the description from the argument
        first_arg = node.arguments&.arguments&.first

        case first_arg
        when Prism::StringNode
          first_arg.content
        when Prism::SymbolNode
          first_arg.value.to_s
        when Prism::ConstantReadNode
          first_arg.name.to_s
        when Prism::ConstantPathNode
          first_arg.full_name
        else
          "example at #{relative_location(node)}"
        end
      end

      #: (Prism::CallNode) -> void
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

        @response_builder.add_code_lens(test_item)
        @group_stack.push(test_item)
      end

      #: (Prism::CallNode) -> void
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
        @response_builder.add_code_lens(test_item)
      end

      #: -> ::RubyLsp::Requests::Support::TestItem??
      def find_parent_test_group
        @group_stack.last
      end

      # A node is valid if it has a block and the receiver is RSpec (or nil)
      #: (Prism::CallNode) -> bool
      def valid_group?(node)
        return false if node.block.nil?
        node.receiver.nil? || node.receiver&.slice == "RSpec"
      end

      #: (Prism::CallNode) -> String
      def relative_location(node)
        uri_path = @uri.to_standardized_path #: as !nil
        relative_path = Pathname.new(uri_path).relative_path_from(Pathname.new(@workspace_path))
        "./#{relative_path}:#{node.location.start_line}"
      end
    end
  end
end
