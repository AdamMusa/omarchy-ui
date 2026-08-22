MRuby::Build.new do |conf|
  toolchain :gcc
  conf.gembox "stdlib"
  conf.gembox "stdlib-ext"
  conf.gembox "stdlib-io"
  conf.gembox "math"
  conf.gembox "metaprog"
  conf.gem core: "mruby-bin-mruby"
  conf.gem github: "mattn/mruby-json"
  conf.gem github: "iij/mruby-regexp-pcre"
  conf.gem github: "iij/mruby-env"
  conf.gem github: "iij/mruby-process"
  conf.gem core: "mruby-sleep"
  conf.gem File.expand_path("mrbgem", __dir__)
end
