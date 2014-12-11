#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'dwca-hunter'
opts = { download: false, unpack: false }
opts = { download: false}
opts = {}
DwcaHunter::logger = Logger.new($stdout)
resources = [
  DwcaHunter::ResourceBirdLife.new(opts)
  # DwcaHunter::ResourceMammalSpecies.new(opts)
  # DwcaHunter::ResourceArctos.new(opts)
  # DwcaHunter::ResourceGNUB.new(opts)
  # DwcaHunter::ResourceWikispecies.new(opts),
  # DwcaHunter::ResourceReptilesChecklist.new(opts),
  # DwcaHunter::ResourceFreebase.new(opts),
  # DwcaHunter::ResourceITIS.new(opts),
  # DwcaHunter::ResourceNCBI.new(opts),
  # DwcaHunter::ResourceWoRMS.new(opts)
]
resources.each do |r|
  dh = DwcaHunter.new(r)
  dh.process
end
