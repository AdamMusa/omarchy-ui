# frozen_string_literal: true

require "open3"
require "timeout"

module OmarchyUI
  class CommandTimeout < StandardError; end

  CommandResult = Struct.new(:stdout, :stderr, :status, keyword_init: true) do
    def success? = status.success?
    def exitstatus = status.exitstatus
  end

  module Command
    module_function

    def run(argv, env: {}, chdir: nil, input: "", timeout: nil)
      arguments = normalize_argv(argv)
      options = {}
      options[:chdir] = File.expand_path(chdir) if chdir
      stdin = stdout = stderr = wait_thread = nil
      Open3.popen3(normalize_env(env), *arguments, **options) do |child_stdin, child_stdout, child_stderr, child_wait|
        stdin, stdout, stderr, wait_thread = child_stdin, child_stdout, child_stderr, child_wait
        stdin.write(input.to_s)
        stdin.close
        stdout_reader = Thread.new { stdout.read }
        stderr_reader = Thread.new { stderr.read }
        status = timeout ? Timeout.timeout(Float(timeout)) { wait_thread.value } : wait_thread.value
        return CommandResult.new(stdout: stdout_reader.value, stderr: stderr_reader.value, status:)
      rescue Timeout::Error
        terminate(wait_thread)
        stdout_reader&.join(1)
        stderr_reader&.join(1)
        raise CommandTimeout, "command timed out after #{timeout}s: #{arguments.first}"
      end
    ensure
      [stdin, stdout, stderr].each { |stream| stream&.close unless stream&.closed? }
    end

    def normalize_argv(argv)
      raise ArgumentError, "command must be an argv array" unless argv.is_a?(Array) && !argv.empty?
      argv.map do |argument|
        raise ArgumentError, "command arguments must be strings" unless argument.is_a?(String)
        raise ArgumentError, "command arguments cannot contain NUL" if argument.include?("\0")
        argument
      end
    end
    private_class_method :normalize_argv

    def normalize_env(env)
      raise ArgumentError, "command environment must be a hash" unless env.is_a?(Hash)
      env.to_h { |key, value| [key.to_s, value.to_s] }
    end
    private_class_method :normalize_env

    def terminate(wait_thread)
      Process.kill("TERM", wait_thread.pid)
      Timeout.timeout(1) { wait_thread.value }
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    rescue Timeout::Error
      Process.kill("KILL", wait_thread.pid)
      wait_thread.value
    end
    private_class_method :terminate
  end
end
