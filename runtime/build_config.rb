MRuby::Build.new do |conf|
  toolchain :gcc
  conf.gembox "stdlib"
  conf.gembox "stdlib-ext"
  conf.gembox "stdlib-io"
  conf.gembox "math"
  conf.gembox "metaprog"
  conf.gem core: "mruby-bin-mruby"
  conf.gem github: "mattn/mruby-json", checksum_hash: ENV.fetch("MRUBY_JSON_REVISION")
  conf.gem github: "iij/mruby-regexp-pcre", checksum_hash: ENV.fetch("MRUBY_REGEXP_PCRE_REVISION")
  conf.gem github: "iij/mruby-env", checksum_hash: ENV.fetch("MRUBY_ENV_REVISION")
  conf.gem github: "iij/mruby-process", checksum_hash: ENV.fetch("MRUBY_PROCESS_REVISION")
  conf.gem core: "mruby-sleep"
  conf.gem File.expand_path("mrbgem", __dir__)
end
