# typed: true
# frozen_string_literal: true

require "rspec/core/formatters"
require "rspec/core/formatters/progress_formatter"
require "ruby_lsp/test_reporters/lsp_reporter"

module RubyLsp
  module RSpec
    class RSpecFormatter < ::RSpec::Core::Formatters::ProgressFormatter
      ::RSpec::Core::Formatters.register(
        self,
        :example_passed,
        :example_pending,
        :example_failed,
        :example_started,
        :start_dump,
        :stop,
      )

      def initialize(output)
        super(output)
      end

      def example_started(notification)
        example = notification.example
        uri = uri_for(example)
        id = generate_id(example)
        line = example.location.split(":").last
        RubyLsp::LspReporter.instance.start_test(id: id, uri: uri, line: line)
      end

      def example_passed(notification)
        super(notification)

        example = notification.example
        uri = uri_for(example)
        id = generate_id(example)
        RubyLsp::LspReporter.instance.record_pass(id: id, uri: uri)
      end

      def example_failed(notification)
        super(notification)

        example = notification.example
        uri = uri_for(example)
        id = generate_id(example)
        message = notification.message_lines.join("\n")
        message << "\n\n"
        message << notification.formatted_backtrace.map(&method(:adjust_backtrace)).map { |s| "# " + s }.join("\n")
        RubyLsp::LspReporter.instance.record_fail(id: id, message: message, uri: uri)
      end

      def example_pending(notification)
        super(notification)

        example = notification.example
        uri = uri_for(example)
        id = generate_id(example)
        RubyLsp::LspReporter.instance.record_skip(id: id, uri: uri)
      end

      def stop(notification)
        RubyLsp::LspReporter.instance.shutdown
      end

      def uri_for(example)
        absolute_path = File.expand_path(example.file_path)
        URI::Generic.from_path(path: absolute_path)
      end

      def generate_id(example)
        [example, *example.example_group.parent_groups].reverse.map(&:location).join("::")
      end

      def adjust_backtrace(backtrace)
        # Correct the backtrace entry so that vscode recognized it as a link to open
        parts = backtrace.split(":", 3)
        parts[0].sub(/^\./, "file://" + File.expand_path(".")) + ":" + parts[1] + " : " + parts[2]
      end
    end
  end
end
