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

      sig { params(uri: URI::Generic, emitter: EventEmitter, message_queue: Thread::Queue).void }
      def initialize(uri, emitter, message_queue)
        @_response = T.let([], ResponseType)
        @path = T.let(uri.to_standardized_path, T.nilable(String))
        emitter.register(self, :on_command, :on_command_call, :on_call)

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

        super(emitter, message_queue)
      end

      sig { params(node: SyntaxTree::CallNode).void }
      def on_call(node)
        add_group_code_lens(node)
      end

      sig { params(node: SyntaxTree::CommandCall).void }
      def on_command_call(node)
        add_group_code_lens(node)
      end

      sig { params(node: SyntaxTree::Command).void }
      def on_command(node)
        message_value = node.message.value
        if message_value == "it"
          argument = node.arguments.parts.first

          name = case argument
          when SyntaxTree::StringLiteral
            argument.parts.first.value
          when SyntaxTree::VarRef
            argument.value.value
          end

          add_test_code_lens(node, name: name, kind: :example)
        elsif message_value == "describe" || message_value == "context"
          add_group_code_lens(node)
        end
      end

      private

      sig do
        params(node: T.any(
          SyntaxTree::StringLiteral,
          SyntaxTree::ConstPathRef,
          SyntaxTree::ConstRef,
          SyntaxTree::TopConstRef,
          SyntaxTree::VarRef,
        )).returns(T.nilable(String))
      end
      def get_group_name(node)
        case node
        when SyntaxTree::StringLiteral
          node.parts.first.value
        when SyntaxTree::ConstPathRef, SyntaxTree::ConstRef, SyntaxTree::TopConstRef
          full_constant_name(node)
        when SyntaxTree::VarRef
          node.value.value
        end
      end

      sig { params(node: T.any(SyntaxTree::CallNode, SyntaxTree::CommandCall, SyntaxTree::Command)).void }
      def add_group_code_lens(node)
        return unless node.message.value == "describe" || node.message.value == "context"

        case node
        when SyntaxTree::CommandCall, SyntaxTree::CallNode
          return if node.receiver && node.receiver.value.value != "RSpec"
        end

        argument = case node
        when SyntaxTree::CallNode
          node.arguments.arguments.parts.first
        when SyntaxTree::CommandCall, SyntaxTree::Command
          node.arguments.parts.first
        end

        name = get_group_name(argument)

        return unless name

        add_test_code_lens(node, name: name, kind: :group)
      end

      sig { params(node: SyntaxTree::Node, name: String, kind: Symbol).void }
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
