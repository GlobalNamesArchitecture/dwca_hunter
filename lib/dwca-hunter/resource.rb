class DwcaHunter
  class Resource
    attr_reader :url, :uuid, :download_path

    def initialize(opts)
      @needs_download = !(opts[:download] == false)
      @needs_unpack = !(opts[:unpack] == false)
      @download_dir, @download_file = File.split(@download_path)
      prepare_path if needs_download?
    end

    def needs_download?
      @needs_download
    end

    def needs_unpack?
      @needs_unpack
    end

    private
    def prepare_path
      FileUtils.rm_rf(@download_dir)
      FileUtils.mkdir_p(@download_dir)
    end

    def unpack_bz2
      DwcaHunter::logger_write(self.object_id, "Unpacking a bz2 file, it might take a while...")
      Dir.chdir(@download_dir)
      `bunzip2 #{@download_file}`
    end

    def unpack_zip
      DwcaHunter::logger_write(self.object_id, "Unpacking a zip file, it might take a while...")
      Dir.chdir(@download_dir)
      `unzip #{@download_file}`
    end

    def unpack_tar
      DwcaHunter::logger_write(self.object_id, "Unpacking a tar file, it might take a while...")
      Dir.chdir(@download_dir)
      `tar zxvf #{@download_file}`
    end
    
    def generate_dwca
      gen = DarwinCore::Generator.new(File.join(@download_dir, "dwca.tar.gz"))
      gen.add_core(@core, 'taxa.txt')
      @extensions.each_with_index do |extension, i|
        gen.add_extension(extension[:data], extension[:file_name])
      end
      gen.add_meta_xml
      gen.add_eml_xml(@eml)
      gen.pack
      DwcaHunter::logger_write(self.object_id, "DarwinCore Archive file is created")
    end
  end
end


