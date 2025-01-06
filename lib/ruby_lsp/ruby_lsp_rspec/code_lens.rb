# typed: strict
# frozen_string_literal: true

module RubyLsp
  module RSpec
    class CodeLens
      extend T::Sig

      include ::RubyLsp::Requests::Support::Common

      sig do
        params(
          response_builder: ResponseBuilders::CollectionResponseBuilder[Interface::CodeLens],
          uri: URI::Generic,
          dispatcher: Prism::Dispatcher,
          rspec_command: T.nilable(String),
          use_relative_paths: T::Boolean,
        ).void
      end
      def initialize(response_builder, uri, dispatcher, rspec_command: nil, use_relative_paths: false)
        @response_builder = response_builder
        # Listener is only initialized if uri.to_standardized_path is valid
        @path = T.let(T.must(uri.to_standardized_path), String)
        @group_id = T.let(1, Integer)
        @group_id_stack = T.let([], T::Array[Integer])
        @anonymous_example_count = T.let(0, Integer)
        @use_relative_paths = T.let(use_relative_paths, T::Boolean)
        dispatcher.register(self, :on_call_node_enter, :on_call_node_leave)

        @base_command = T.let(
          # The user-configured command takes precedence over inferred command default
          rspec_command || begin
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
          @anonymous_example_count += 1
          "<unnamed-#{@anonymous_example_count}>"
        end
      end

      sig { params(node: Prism::Node, name: String, kind: Symbol).void }
      def add_test_code_lens(node, name:, kind:)
        line_number = node.location.start_line

        path_for_command = if @use_relative_paths
          Pathname.new(@path).relative_path_from(Pathname.new(Dir.pwd)).to_s
        else
          @path
        end
        command = "#{@base_command} #{path_for_command}:#{line_number}"

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
