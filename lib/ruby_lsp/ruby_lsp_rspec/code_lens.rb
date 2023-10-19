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

      sig { params(uri: URI::Generic, dispatcher: Prism::Dispatcher, message_queue: Thread::Queue).void }
      def initialize(uri, dispatcher, message_queue)
        @_response = T.let([], ResponseType)
        @path = T.let(uri.to_standardized_path, T.nilable(String))
        dispatcher.register(self, :on_call_node_enter)

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

        super(dispatcher, message_queue)
      end

      sig { params(node: Prism::CallNode).void }
      def on_call_node_enter(node)
        message_value = node.message
        if message_value == "it"
          name = generate_name(node)
          add_test_code_lens(node, name: name, kind: :example)
        elsif message_value == "describe" || message_value == "context"
          return if node.receiver && node.receiver.name.to_s != "RSpec"

          name = generate_name(node)
          add_test_code_lens(node, name: name, kind: :group)
        end
      end

      sig { params(node: Prism::CallNode).returns(String) }
      def generate_name(node)
        if node.arguments
          argument = node.arguments.arguments.first

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

      private

      sig { params(node: Prism::Node, name: String, kind: Symbol).void }
      def add_test_code_lens(node, name:, kind:)
        return unless @path

        line_number = node.location.start_line
        command = "#{@base_command} #{@path}:#{line_number}"

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
          data: { type: "test", kind: kind },
        )

        @_response << create_code_lens(
          node,
          title: "Run In Terminal",
          command_name: "rubyLsp.runTestInTerminal",
          arguments: arguments,
          data: { type: "test_in_terminal", kind: kind },
        )

        @_response << create_code_lens(
          node,
          title: "Debug",
          command_name: "rubyLsp.debugTest",
          arguments: arguments,
          data: { type: "debug", kind: kind },
        )
      end
    end
  end
end
