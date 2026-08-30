# frozen_string_literal: true

fake_curl = ARGV.shift.to_s
fixture_dir = ARGV.shift.to_s
audit_home = ARGV.shift.to_s
raise "fake curl fixture missing" unless File.file?(fake_curl)
raise "fixture directory missing" unless File.directory?(fixture_dir)
raise "audit home missing" unless File.directory?(audit_home)

plugin_id = "example.http-audit"
ENV["HOME"] = audit_home
result = nil
Dir.chdir(fixture_dir) do
  File.open("manifest.json", "w", 0o600) do |file|
    file.write(JSON.generate("id" => plugin_id))
  end
  result = Zui::Command.run(
    [fake_curl, "https://person:secret@example.invalid/private/path?token=hidden#fragment"],
    timeout: 2,
    max_output_bytes: 4096
  )
  raise "fake HTTP command failed" unless result.success?
end

audit_path = File.join(audit_home, ".local", "state", "omarchy-ui-audit", "#{plugin_id}.jsonl")
raise "HTTP audit was not written" unless File.file?(audit_path)
event = JSON.parse(File.read(audit_path).lines.last)
raise "wrong audit type" unless event["type"] == "http"
raise "HTTP method was not recorded" unless event["method"] == "GET"
raise "credentials or query leaked" unless event["url"] == "https://example.invalid/private/path"
raise "process response was not recorded" unless event["exit_status"] == 0
raise "response size was not recorded" unless event["response_bytes"] == result.stdout.bytesize
raise "duration was not bounded" unless event["duration_ms"].between?(0, 3_600_000)

puts "omarchy-ui-runtime HTTP audit: OK"
