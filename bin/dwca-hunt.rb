#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'dwca-hunter'
opts = { download: false, unpack: false }
opts = {}
DwcaHunter::logger = Logger.new($stdout)
resources = [
  # DwcaHunter::ResourceWikispecies.new(opts), 
  DwcaHunter::ResourceFreebase.new(opts),
  # DwcaHunter::ResourceITIS.new(opts),
]
resources.each do |r|
  dh = DwcaHunter.new(r)
  dh.process
end
