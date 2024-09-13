require "xz"

module DwcaHunter
  # Resource for FishBase
  class ResourceEOL < DwcaHunter::Resource
    attr_reader :title, :abbr

    def initialize(opts = {}) # download: false, unpack: false})
      @command = "eol"
      @title = "Encyclopedia of Life"
      @abbr = "EOL"
      @url = "https://eol.org/data/full_provider_ids.csv.gz"
      @uuid = "dba5f880-a40d-479b-a1ad-a646835edde4"
      @download_dir = File.join(Dir.tmpdir, "dwca_hunter", "eol")
      @download_path = File.join(@download_dir, "eol.csv.gz")
      @extensions = []
      super
    end

    def unpack
      unpack_gzip
    end

    def make_dwca
      organize_data
      generate_dwca
    end

    private

    def organize_data
      uniq = {}
      DwcaHunter.logger_write(object_id,
                              "Organizing data")
      count = 0
      # snp = ScientificNameParser.new
      @data = CSV.open(@download_path[0...-3],
                       col_sep: ",", headers: true).
              each_with_object([]) do |row, data|
        count += 1
        DwcaHunter.logger_write(object_id, "Raw file row #{count}") if (count % 1_000_000).zero?
        id = row["page_id"].strip
        name = row["preferred_canonical_for_page"].strip
        k = "#{id}|#{name}"
        next if uniq.key?(k)

        data << { taxon_id: id,
                  local_id: id,
                  scientific_name: name }
        uniq[k] = true
      end
    end

    def generate_dwca
      DwcaHunter.logger_write(object_id,
                              "Creating DarwinCore Archive file")
      core_init
      eml_init
      DwcaHunter.logger_write(object_id, "Assembling Core Data")
      count = 0
      @data.each do |d|
        count += 1
        DwcaHunter.logger_write(object_id, "Core row #{count}") if (count % 1_000_000).zero?
        @core << [d[:taxon_id], d[:local_id],
                  d[:scientific_name]]
      end
      super
    end

    def eml_init
      @eml = {
        id: @uuid,
        title: @title,
        authors: [],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin" }
        ],
        abstract: "Global access to knowledge about life on Earth",
        url: "http://www.eol.org"
      }
    end

    def core_init
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
                "http://globalnames.org/terms/localID",
                "http://rs.tdwg.org/dwc/terms/scientificName"]]
    end
  end
end
