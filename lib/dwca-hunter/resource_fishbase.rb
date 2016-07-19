class DwcaHunter
  # Resource for FishBase
  class ResourceFishbase < DwcaHunter::Resource
    attr_reader :title, :abbr
    def initialize(opts = {})
      @title = "FishBase Cached"
      @abbr = "FishBase"
      @uuid = "bacd21f0-44e0-43e2-914c-70929916f257"
      @download_path = File.join(DEFAULT_TMP_DIR, "dwca_hunter", "fishbase",
                                 "fishbase.tsv")
      @url = "https://github.com/jhpoelen/fishbase_taxon_cache/releases/" \
             "download/v0.1.1/fishbase_taxon_cache-assembly-0.1.1.jar"
      # @url = "https://github.com/jhpoelen/fishbase_taxon_cache/" \
      #        "releases/download/v0.1.1/fishbase_taxon_cache.tsv.gz"
      super
    end

    def download
      FileUtils.cp(File.join(__dir__, "..", "..", "files",
                             "fishbase_taxon_cache.tsv"), @download_path)
    end

    def unpack
    end

    def make_dwca
      organize_data
    end

    private

    def organize_data
      DwcaHunter::logger_write(self.object_id,
                               "Organizing data")
      # snp = ScientificNameParser.new
      @data = CSV.open(@download_path, col_sep: "\t")
        .each_with_object([]) do |row, data|
        puts row
      end
    end
  end
end
