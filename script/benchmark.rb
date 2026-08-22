# frozen_string_literal: true

require "json"
require "open3"
require "rbconfig"

ROOT = File.expand_path("..", __dir__)
MAIN = File.join(ROOT, "main.rb")
ITERATIONS = Integer(ENV.fetch("ITERATIONS", "500"))

def monotonic
  Process.clock_gettime(Process::CLOCK_MONOTONIC)
end

def percentile(values, fraction)
  sorted = values.sort
  sorted[[(sorted.length * fraction).ceil - 1, 0].max]
end

def read_message(io)
  line = io.gets
  raise "Ruby UI process closed its output" unless line

  JSON.parse(line)
end

def find_control(node, text)
  return node["id"] if node.dig("props", "text") == text

  Array(node["children"]).each do |child|
    found = find_control(child, text)
    return found if found
  end
  nil
end

started_at = monotonic
stdin, stdout, stderr, wait_thread = Open3.popen3(RbConfig.ruby, MAIN, chdir: ROOT)
ready = read_message(stdout)
ready_at = monotonic
render = read_message(stdout)
render_at = monotonic

raise "unexpected startup protocol" unless ready["type"] == "ready" && render["type"] == "render"

increment_id = find_control(render.dig("surfaces", "counter"), "Increment")
raise "increment button not found" unless increment_id

latencies = []
patch_latencies = []
rss_kib = 0
ITERATIONS.times do |index|
  sent_at = monotonic
  stdin.puts(JSON.generate(
    "v" => 1,
    "type" => "event",
    "surface" => "counter",
    "id" => increment_id,
    "event" => "click",
    "seq" => index,
    "payload" => { "diagnostics" => index == ITERATIONS - 1 }
  ))
  stdin.flush

  loop do
    message = read_message(stdout)
    if message["type"] == "patch" && message["id"] == "count"
      patch_latencies << (monotonic - sent_at) * 1000.0
      next
    end
    next unless message["type"] == "ack" && message["seq"] == index

    latencies << (monotonic - sent_at) * 1000.0
    rss_kib = message["rss_kib"].to_i if message["rss_kib"]
    break
  end
end

stdin.close
unless wait_thread.join(2)
  Process.kill("TERM", wait_thread.pid)
  wait_thread.join
end
stderr_output = stderr.read

result = {
  "ruby" => RUBY_DESCRIPTION,
  "iterations" => ITERATIONS,
  "process_startup_ms" => ((ready_at - started_at) * 1000.0).round(3),
  "initial_render_after_ready_ms" => ((render_at - ready_at) * 1000.0).round(3),
  "event_round_trip_ms" => {
    "median" => percentile(latencies, 0.50).round(3),
    "p95" => percentile(latencies, 0.95).round(3),
    "max" => latencies.max.round(3)
  },
  "ruby_to_stdio_patch_ms" => {
    "median" => percentile(patch_latencies, 0.50).round(3),
    "p95" => percentile(patch_latencies, 0.95).round(3),
    "max" => patch_latencies.max.round(3)
  },
  "events_per_second" => (ITERATIONS / (latencies.sum / 1000.0)).round(1),
  "ruby_rss_kib" => rss_kib,
  "stderr" => stderr_output.strip
}

puts JSON.pretty_generate(result)
