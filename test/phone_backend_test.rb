# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require_relative "../lib/omarchy_ui"
require_relative "../examples/omarchy-phone/lib/phone_backend"

class PhoneBackendTest < Minitest::Test
  FakeCommandResult = Struct.new(:stdout, :stderr, :success?)

  class FakeBackend < PhoneBackend
    attr_reader :commands

    def initialize(responses, state_dir:)
      @responses = responses
      @commands = []
      super(state_dir:)
    end

    private

    def command(argv, timeout:)
      @commands << [argv, timeout]
      @responses.fetch(argv, FakeCommandResult.new("", "", false))
    end

    def available?(_program) = true
  end

  def test_snapshot_merges_attached_mdns_android_and_ios_devices
    Dir.mktmpdir do |directory|
      backend = FakeBackend.new(
        {
          ["adb", "devices", "-l"] => success("List of devices attached\nUSB1 device model:Pixel_9\n"),
          ["adb", "mdns", "services"] => success("Kitchen\\032Phone _adb-tls-connect._tcp. 10.0.0.8:37123\n"),
          ["idevice_id", "-l"] => success("IOS1\n"),
          ["ideviceinfo", "-u", "IOS1", "-k", "DeviceName"] => success("Alice's iPhone\n"),
          ["ideviceinfo", "-u", "IOS1", "-k", "ProductType"] => success("iPhone17,1\n")
        }, state_dir: directory
      )

      devices = backend.snapshot.fetch(:devices)
      assert_equal %w[IOS1 USB1 10.0.0.8:37123], devices.map { |device| device.fetch(:id) }
      assert_equal "Kitchen Phone", devices.last.fetch(:name)
      assert_equal "Wi-Fi", devices.last.fetch(:transport)
      assert_equal "Alice's iPhone", devices.first.fetch(:name)
    end
  end

  def test_actions_use_argument_arrays_without_a_shell
    Dir.mktmpdir do |directory|
      argv = ["adb", "pair", "10.0.0.8:1234; touch /tmp/nope", "123456"]
      backend = FakeBackend.new({ argv => success("Successfully paired\n") }, state_dir: directory)
      result = backend.pair_android(argv[2], argv[3])

      assert result.ok
      assert_equal "Successfully paired", result.message
      assert_equal argv, backend.commands.last.first
    end
  end

  private

  def success(stdout) = FakeCommandResult.new(stdout, "", true)
end
