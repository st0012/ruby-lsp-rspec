# typed: false
# frozen_string_literal: true

require "spec_helper"
require "socket"
require "open3"
require "json"
require "stringio"
require "ruby_lsp/ruby_lsp_rspec/rspec_formatter"

RSpec.describe "RubyLsp::RSpec::RSpecFormatter" do
  it "sends correct LSP events during test execution" do
    fixture_path = File.expand_path("spec/fixtures/rspec_example_spec.rb")

    server = TCPServer.new("localhost", 0)
    port = server.addr[1].to_s
    events = []
    socket = nil #: TCPSocket?

    receiver = Thread.new do
      socket = server.accept
      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true)

      loop do
        headers = socket.gets("\r\n\r\n")
        break unless headers

        content_length = headers[/Content-Length: (\d+)/i, 1].to_i
        raw_message = socket.read(content_length)

        event = JSON.parse(raw_message)
        events << event

        break if event["method"] == "finish"
      end
    end

    _stdin, _stdout, _stderr, wait_thr = Open3
      .popen3(
        ENV.to_hash.merge({
          "RUBY_LSP_TEST_RUNNER" => "run",
          "RUBY_LSP_REPORTER_PORT" => port,
        }),
        "bundle",
        "exec",
        "rspec",
        fixture_path,
      )

    Timeout.timeout(5) do
      receiver.join
    end

    wait_thr.join
    socket&.close

    expected = [
      {
        "method" => "start",
        "params" => {
          "id" => "./spec/fixtures/rspec_example_spec.rb:11::./spec/fixtures/rspec_example_spec.rb:12::./spec/fixtures/rspec_example_spec.rb:13",
          "line" => "13",
          "uri" => "file://#{fixture_path}",
        },
      },
      {
        "method" => "pass",
        "params" => {
          "id" => "./spec/fixtures/rspec_example_spec.rb:11::./spec/fixtures/rspec_example_spec.rb:12::./spec/fixtures/rspec_example_spec.rb:13",
          "uri" => "file://#{fixture_path}",
        },
      },
      {
        "method" => "start",
        "params" => {
          "id" => "./spec/fixtures/rspec_example_spec.rb:11::./spec/fixtures/rspec_example_spec.rb:12::./spec/fixtures/rspec_example_spec.rb:17",
          "line" => "17",
          "uri" => "file://#{fixture_path}",
        },
      },
      {
        "method" => "fail",
        "params" => {
          "id" => "./spec/fixtures/rspec_example_spec.rb:11::./spec/fixtures/rspec_example_spec.rb:12::./spec/fixtures/rspec_example_spec.rb:17",
          "message" => %r{Failure/Error: expect\(2\).to eq\(1\)\n\n  expected: 1\n       got: 2\n\n  \(compared using ==\)\n\n# file://#{fixture_path}:18 : in [`']block \(3 levels\) in <top \(required\)>'},
          "uri" => "file://#{fixture_path}",
        },
      },
      {
        "method" => "start",
        "params" => {
          "id" => "./spec/fixtures/rspec_example_spec.rb:11::./spec/fixtures/rspec_example_spec.rb:12::./spec/fixtures/rspec_example_spec.rb:21",
          "line" => "21",
          "uri" => "file://#{fixture_path}",
        },
      },
      {
        "method" => "skip",
        "params" => {
          "id" => "./spec/fixtures/rspec_example_spec.rb:11::./spec/fixtures/rspec_example_spec.rb:12::./spec/fixtures/rspec_example_spec.rb:21",
          "uri" => "file://#{fixture_path}",
        },
      },
      {
        "method" => "start",
        "params" => {
          "id" => "./spec/fixtures/rspec_example_spec.rb:11::./spec/fixtures/rspec_example_spec.rb:12::./spec/fixtures/rspec_example_spec.rb:26",
          "line" => "26",
          "uri" => "file://#{fixture_path}",
        },
      },
      {
        "method" => "pass",
        "params" => {
          "id" => "./spec/fixtures/rspec_example_spec.rb:11::./spec/fixtures/rspec_example_spec.rb:12::./spec/fixtures/rspec_example_spec.rb:26",
          "uri" => "file://#{fixture_path}",
        },
      },
      {
        "method" => "start",
        "params" => {
          "id" => "./spec/fixtures/rspec_example_spec.rb:11::./spec/fixtures/rspec_example_spec.rb:12::./spec/fixtures/rspec_example_spec.rb:30",
          "line" => "30",
          "uri" => "file://#{fixture_path}",
        },
      },
      {
        "method" => "fail",
        "params" => {
          "id" => "./spec/fixtures/rspec_example_spec.rb:11::./spec/fixtures/rspec_example_spec.rb:12::./spec/fixtures/rspec_example_spec.rb:30",
          "message" => %r{Failure/Error: raise "oops"\n\nRuntimeError:\n  oops\n\n# file://#{fixture_path}:31 : in [`']block \(3 levels\) in <top \(required\)>'},
          "uri" => "file://#{fixture_path}",
        },
      },
      { "method" => "finish", "params" => {} },
    ]

    expect(events).to match(expected)
  end

  describe "RubyLsp::RSpec::RSpecFormatter notifications" do
    let(:output) { StringIO.new }
    let(:formatter) { RubyLsp::RSpec::RSpecFormatter.new(output) }
    let(:notification) { double("Notification") }
    let(:example) { double("Example") }

    before do
      allow(notification).to receive(:example).and_return(example)
      allow(example).to receive(:file_path).and_return("spec/fixtures/rspec_example_spec.rb")
      allow(example).to receive(:location).and_return("./spec/fixtures/rspec_example_spec.rb:13")
      allow(example).to receive(:example_group).and_return(double("ExampleGroup", parent_groups: []))
    end

    it "is a subclass of ProgressFormatter" do
      expect(RubyLsp::RSpec::RSpecFormatter.superclass).to eq(RSpec::Core::Formatters::ProgressFormatter)
    end

    it "registers necessary notifications with RSpec" do
      registered_notifications = RSpec::Core::Formatters::Loader.formatters[RubyLsp::RSpec::RSpecFormatter]

      expect(registered_notifications).to match_array([
        :example_passed,
        :example_pending,
        :example_failed,
        :example_started,
        :start_dump,
        :stop,
      ])
    end

    it "invokes ProgressFormatter's example_passed" do
      expect_any_instance_of(RSpec::Core::Formatters::ProgressFormatter).to receive(:example_passed)

      formatter.example_passed(notification)
    end

    it "invokes ProgressFormatter's example_failed" do
      allow(notification).to receive(:message_lines).and_return(["message lines"])
      allow(notification).to receive(:formatted_backtrace).and_return(["spec/example_spec.rb:13:in `something'"])

      expect_any_instance_of(RSpec::Core::Formatters::ProgressFormatter).to receive(:example_failed)

      formatter.example_failed(notification)
    end

    it "invokes ProgressFormatter's example_pending" do
      expect_any_instance_of(RSpec::Core::Formatters::ProgressFormatter).to receive(:example_pending)

      formatter.example_pending(notification)
    end

    it "invokes ProgressFormatter's start_dump" do
      dump_notification = double("DumpNotification")
      expect_any_instance_of(RSpec::Core::Formatters::ProgressFormatter).to receive(:start_dump)

      formatter.start_dump(dump_notification)
    end
  end
end
