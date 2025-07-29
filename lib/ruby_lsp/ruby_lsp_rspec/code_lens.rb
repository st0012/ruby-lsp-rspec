# typed: strict
# frozen_string_literal: true

module RubyLsp
  module RSpec
    class CodeLens
      include ::RubyLsp::Requests::Support::Common

      #: (ResponseBuilders::CollectionResponseBuilder[Interface::CodeLens], URI::Generic, Prism::Dispatcher, String, ?debug: bool) -> void
      def initialize(response_builder, uri, dispatcher, rspec_command, debug: false)
        @response_builder = response_builder
        # Listener is only initialized if uri.to_standardized_path is valid
        path = uri.to_standardized_path #: as !nil
        @path = path #: String
        @group_id = 1 #: Integer
        @group_id_stack = [] #: Array[Integer]
        @rspec_command = rspec_command
        @anonymous_example_count = 0 #: Integer
        dispatcher.register(self, :on_call_node_enter, :on_call_node_leave)

        @debug = debug
      end

      #: (Prism::CallNode) -> void
      def on_call_node_enter(node)
        case node.message
        when "example", "it", "specify", "scenario"
          name = generate_name(node)
          add_test_code_lens(node, name: name, kind: :example)
        when "context", "describe", "feature"
          return unless valid_group?(node)

          name = generate_name(node)
          add_test_code_lens(node, name: name, kind: :group)

          @group_id_stack.push(@group_id)
          @group_id += 1
        end
      end

      #: (Prism::CallNode) -> void
      def on_call_node_leave(node)
        case node.message
        when "context", "describe", "feature"
          return unless valid_group?(node)

          @group_id_stack.pop
        end
      end

      private

      #: (String) -> void
      def log_message(message)
        puts "[#{self.class}]: #{message}"
      end

      #: (Prism::CallNode) -> bool
      def valid_group?(node)
        !(node.block.nil? || (node.receiver && node.receiver&.slice != "RSpec"))
      end

      #: (Prism::CallNode) -> String
      def generate_name(node)
        arguments = node.arguments&.arguments

        if arguments
          argument = arguments.first

          case argument
          when Prism::StringNode
            argument.content
          when Prism::CallNode
            "<#{argument.name}>"
          when nil
            ""
          else
            argument.slice
          end
        else
          @anonymous_example_count += 1
          "<unnamed-#{@anonymous_example_count}>"
        end
      end

      #: (Prism::Node, name: String, kind: Symbol) -> void
      def add_test_code_lens(node, name:, kind:)
        line_number = node.location.start_line
        command = "#{@rspec_command} #{@path}:#{line_number}"

        log_message("Full command: `#{command}`") if @debug

        grouping_data = { group_id: @group_id_stack.last, kind: kind }
        grouping_data[:id] = @group_id if kind == :group

        arguments = [
          @path,
          name,
          command,
          {
            start_line: node.location.start_line - 1,
            start_column: node.location.start_column,
            end_line: node.location.end_line - 1,
            end_column: node.location.end_column,
          },
        ]

        @response_builder << create_code_lens(
          node,
          title: "Run",
          command_name: "rubyLsp.runTest",
          arguments: arguments,
          data: { type: "test", **grouping_data },
        )

        @response_builder << create_code_lens(
          node,
          title: "Run In Terminal",
          command_name: "rubyLsp.runTestInTerminal",
          arguments: arguments,
          data: { type: "test_in_terminal", **grouping_data },
        )

        @response_builder << create_code_lens(
          node,
          title: "Debug",
          command_name: "rubyLsp.debugTest",
          arguments: arguments,
          data: { type: "debug", **grouping_data },
        )
      end
    end
  end
end
