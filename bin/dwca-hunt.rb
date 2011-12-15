#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'dwca-hunter'
opts = { download: false, unpack: false }
# opts = {}
DwcaHunter::logger = Logger.new($stdout)
r = DwcaHunter::ResourceWikispecies.new(opts)
dh = DwcaHunter.new(r)
dh.process
