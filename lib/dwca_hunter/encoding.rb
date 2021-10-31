# frozen_string_literal: true

module DwcaHunter
  # Encoding module fixes encoding issues with data
  module Encoding
    def self.latin1_to_utf8(file_path)
      new_file = "#{file_path}.utf_8"
      puts "Creating #{new_file}"
      r = File.open(file_path)
      w = File.open(new_file, "w:utf-8")
      he = HTMLEntities.new
      r.each do |l|
        l = l.encode("UTF-8", "ISO-8859-1", invalid: :replace, replace: "�")
        l = he.decode(l)
        w.write l
      end
      r.close
      w.close
      new_file
    end
  end
end
