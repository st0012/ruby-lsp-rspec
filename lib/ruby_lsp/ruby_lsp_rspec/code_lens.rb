# typed: strict
# frozen_string_literal: true

module RubyLsp
  module RSpec
    class CodeLens < ::RubyLsp::Listener
      extend T::Sig
      extend T::Generic

      include ::RubyLsp::Requests::Support::Common

      ResponseType = type_member { { fixed: T::Array[::RubyLsp::Interface::CodeLens] } }

      sig { override.returns(ResponseType) }
      attr_reader :_response

      sig { params(uri: URI::Generic, dispatcher: Prism::Dispatcher).void }
      def initialize(uri, dispatcher)
        @_response = T.let([], ResponseType)
        # Listener is only initialized if uri.to_standardized_path is valid
        @path = T.let(T.must(uri.to_standardized_path), String)
        @group_id = T.let(1, Integer)
        @group_id_stack = T.let([], T::Array[Integer])
        dispatcher.register(self, :on_call_node_enter, :on_call_node_leave)

        @base_command = T.let(
          begin
            cmd = if File.exist?(File.join(Dir.pwd, "bin", "rspec"))
              "bin/rspec"
            else
              "rspec"
            end

            if File.exist?("Gemfile.lock")
              "bundle exec #{cmd}"
            else
              cmd
            end
          end,
          String,
        )

        super(dispatcher)
      end

      sig { params(node: Prism::CallNode).void }
      def on_call_node_enter(node)
        case node.message
        when "example", "it", "specify"
          name = generate_name(node)
          add_test_code_lens(node, name: name, kind: :example)
        when "context", "describe"
          return unless valid_group?(node)

          name = generate_name(node)
          add_test_code_lens(node, name: name, kind: :group)

          @group_id_stack.push(@group_id)
          @group_id += 1
        end
      end

      sig { params(node: Prism::CallNode).void }
      def on_call_node_leave(node)
        case node.message
        when "context", "describe"
          return unless valid_group?(node)

          @group_id_stack.pop
        end
      end

      private

      sig { params(node: Prism::CallNode).returns(T::Boolean) }
      def valid_group?(node)
        !(node.block.nil? || (node.receiver && node.receiver&.slice != "RSpec"))
      end

      sig { params(node: Prism::CallNode).returns(String) }
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
          "<unnamed>"
        end
      end

      sig { params(node: Prism::Node, name: String, kind: Symbol).void }
      def add_test_code_lens(node, name:, kind:)
        line_number = node.location.start_line
        command = "#{@base_command} #{@path}:#{line_number}"

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

        @_response << create_code_lens(
          node,
          title: "Run",
          command_name: "rubyLsp.runTest",
          arguments: arguments,
          data: { type: "test", **grouping_data },
        )

        @_response << create_code_lens(
          node,
          title: "Run In Terminal",
          command_name: "rubyLsp.runTestInTerminal",
          arguments: arguments,
          data: { type: "test_in_terminal", **grouping_data },
        )

        @_response << create_code_lens(
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
