class DwcaHunter
  module Encoding
    def self.latin1_to_utf8(file_path)
      conv = Iconv.new('UTF-8', 'ISO-8859-1')
      new_file = file_path + ".utf_8"
      puts "Creating %s" % new_file
      r = open(file_path)
      w = open(new_file, 'w:utf-8')
      r.each do |l|
        l = conv.iconv(l)
        w.write l
      end
      r.close
      w.close
      new_file
    end
  end
end
