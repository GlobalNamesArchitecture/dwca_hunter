module DwcaHunter
  # Resource for FishBase
  class ResourceFishbase < DwcaHunter::Resource
    attr_reader :title, :abbr
    def initialize(opts = {})
      @command = "fishbase"
      @title = "FishBase Cache"
      @abbr = "FishBase Cache"
      @uuid = "bacd21f0-44e0-43e2-914c-70929916f257"
      @download_path = File.join(Dir.tmpdir, "dwca_hunter", "fishbase",
                                 "fishbase.tsv")
      @extensions = []
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
      generate_dwca
    end

    private

    def organize_data
      ranks = %i(class order family sub_family genus species)
      DwcaHunter::logger_write(self.object_id,
                               "Organizing data")
      # snp = ScientificNameParser.new
      @data = CSV.open(@download_path, col_sep: "\t")
        .each_with_object([]) do |row, data|
        cl = Hash[ranks.zip(row[4].split("|"))]
        data << { taxon_id: row[0],
                  local_id: row[0],
                  scientific_name: row[1],
                  rank: row[2],
                  source: row[7]
                }.merge(cl)

      end
    end

    def generate_dwca
      DwcaHunter::logger_write(self.object_id,
                               'Creating DarwinCore Archive file')
      core_init
      eml_init
      DwcaHunter::logger_write(self.object_id, 'Assembling Core Data')
      count = 0
      @data.each do |d|
        count += 1
        if count % 10000 == 0
          DwcaHunter::logger_write(self.object_id, "Core row #{count}")
        end
        @core << [d[:taxon_id], d[:taxon_id], d[:taxon_id],
                  d[:scientific_name], d[:rank],
                  d[:class], d[:order], d[:family], d[:genus],
                  d[:source]]
      end
      super
    end

    def eml_init
      @eml = {
        id: @uuid,
        title: @title,
        authors: [],
        metadata_providers: [
          { first_name: "Jorrit",
            last_name: "Poelen",
          }
      ],
        abstract: "FishBase is a global species database of fish species" \
                  "(specifically finfish). It is the largest and the most" \
                  "extensively accessed online database of finfish",
        url: "http://www.fishbase.org"
      }
    end

    def core_init
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
                "http://globalnames.org/terms/localID",
                "http://rs.tdwg.org/dwc/terms/acceptedNameUsageID",
                "http://rs.tdwg.org/dwc/terms/scientificName",
                "http://rs.tdwg.org/dwc/terms/taxonRank",
                "http://rs.tdwg.org/dwc/terms/class",
                "http://rs.tdwg.org/dwc/terms/order",
                "http://rs.tdwg.org/dwc/terms/family",
                "http://rs.tdwg.org/dwc/terms/genus",
                "http://purl.org/dc/terms/source"]]
    end
  end
end
