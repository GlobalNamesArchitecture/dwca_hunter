# frozen_string_literal: true

class DwcaHunter
  # Harvesting resource for Open Tree of Life
  class ResourceOpenTree < DwcaHunter::Resource
    def initialize(opts = {})
      @title = "Open Tree of Life Reference Taxonomy"
      @uuid = "e10865e2-cdd9-4f97-912f-08f3d5ef49f7"
      @data = []
      @extensions = []
      @count = 1
      @clades = {}
      @url = "http://opendata.globalnames.org/id-crossmap/ott2.10draft11.tgz"
      @download_path = File.join(DEFAULT_TMP_DIR, "dwca_hunter",
                                 "opentree", "data.tar.gz")
      super
    end

    def unpack
      unpack_tar if @needs_unpack
    end

    def make_dwca
      DwcaHunter.logger_write(object_id, "Extracting data")
      collect_data
      generate_dwca
    end

    def download
      return unless @needs_download
      DwcaHunter.logger_write(object_id, "Downloading file -- "\
                               "it will take some time...")
      dlr = DwcaHunter::Downloader.new(url, @download_path)
      dlr.download
    end

    private

    def collect_data
      set_vars
      classification
    end

    def set_vars
      @taxonomy = File.join(@download_dir, "ott", "taxonomy.tsv")
      @synonyms = File.join(@download_dir, "ott", "synonyms.tsv")
    end

    def classification
      DwcaHunter.logger_write(object_id, "Building classification")
      open(@taxonomy).each_with_index do |line, i|
        if ((i + 1) % BATCH_SIZE).zero?
          DwcaHunter.logger_write(object_id,
                                  "Traversed #{i + 1} taxonomy lines")
        end
        puts line.split("|").map(&:strip).join("|")
      end
    end

    def generate_dwca
    end
  end
end
