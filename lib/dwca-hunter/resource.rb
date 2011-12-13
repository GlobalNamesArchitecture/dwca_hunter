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
      DwcaHunter::logger_write(self.object_id, "Unpacking bz2 file, it might take a while...")
      Dir.chdir(@download_dir)
      `bunzip2 #{@download_file}`
    end
  end
end


