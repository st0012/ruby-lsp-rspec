# typed: false
# frozen_string_literal: true

require "spec_helper"
require "socket"
require "open3"
require "json"

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
          "uri" => "file://#{fixture_path}",
        },
      },
      {
        "method" => "fail",
        "params" => {
          "id" => "./spec/fixtures/rspec_example_spec.rb:11::./spec/fixtures/rspec_example_spec.rb:12::./spec/fixtures/rspec_example_spec.rb:17",
          "message" => "\nexpected: 1\n     got: 2\n\n(compared using ==)\n",
          "uri" => "file://#{fixture_path}",
        },
      },
      {
        "method" => "start",
        "params" => {
          "id" => "./spec/fixtures/rspec_example_spec.rb:11::./spec/fixtures/rspec_example_spec.rb:12::./spec/fixtures/rspec_example_spec.rb:21",
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
          "uri" => "file://#{fixture_path}",
        },
      },
      {
        "method" => "fail",
        "params" => {
          "id" => "./spec/fixtures/rspec_example_spec.rb:11::./spec/fixtures/rspec_example_spec.rb:12::./spec/fixtures/rspec_example_spec.rb:30",
          "message" => "oops",
          "uri" => "file://#{fixture_path}",
        },
      },
      { "method" => "finish", "params" => {} },
    ]

    expect(events).to eq(expected)
  end
end
