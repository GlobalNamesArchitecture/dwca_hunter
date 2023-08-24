# frozen_string_literal: true

module DwcaHunter
  class ResourceRuhoff < DwcaHunter::Resource
    def initialize(opts = { download: true })
      @parser = Biodiversity::Parser
      @command = "ruhoff"
      @title = "Ruhoff 1980"
      @url = "https://github.com/gnames/ds-ruhoff-mollusca/blob/master/data/07-fmt-names.csv?raw=true"
      @UUID = "5413758a-7fd8-4db9-b06b-f780f8688f2a"
      @download_path = File.join(Dir.tmpdir,
        "dwca_hunter",
        "ruhoff",
        "data.csv")
      @synonyms = []
      @names = []
      @vernaculars = []
      @extensions = []
      @synonyms_hash = {}
      @vernaculars_hash = {}
      super(opts)
    end

    def download
      DwcaHunter.logger_write(object_id, "Downloading")
      `curl -s -L #{@url} -o #{@download_path}`
    end

    def unpack
    end

    def make_dwca
      DwcaHunter.logger_write(object_id, "Extracting data")
      get_names
      generate_dwca
    end

    private

    def get_names
      Dir.chdir(@download_dir)
      collect_names
    end

    def rank(name_string) 
      res = ""
      parsed = @parser.parse(name_string)
      if parsed[:parsed]
        if parsed[:cardinality] == 3
          return "subspecies"
        end
      end
      return "species"
    end

    def collect_names
      @names_index = {}
      file = CSV.open(File.join(@download_path),
        headers: true)
      count = 0
      file.each do |row|
        count += 1
        kingdom = "Animalia"
        phylum = "Mollusca"
        taxon_id = format("gn_%05d", count) 
        name_string = row["Name"].to_s.strip
        rank = rank(name_string)
        next if name_string.strip.empty?

        @names << {
          taxon_id: taxon_id,
          kingdom: kingdom,
          phylum: phylum,
          name_string: name_string,
          rank: rank,
          nom_code: "ICZN"
        }
      end
    end

    def generate_dwca
      DwcaHunter.logger_write(object_id, "Creating DarwinCore Archive file")
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
                "http://rs.tdwg.org/dwc/terms/scientificName",
                "http://rs.tdwg.org/dwc/terms/kingdom",
                "http://rs.tdwg.org/dwc/terms/phylum",
                "http://rs.tdwg.org/dwc/terms/rank",
                "http://rs.tdwg.org/dwc/terms/nomenclaturalCode"]]
      @names.each do |n|
        @core << [n[:taxon_id], n[:name_string],
                  n[:kingdom], n[:phylum], n[:rank],
                  n[:nom_code]]
      end

      @eml = {
        id: @uuid,
        title: @title,
        authors: [
          { first_name: "Florence A.",
            last_name: "Ruhoff" }
        ],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
            email: "dmozzherin@gmail.com" }
        ],
        abstract: "Index to the species of Mollusca introduced " \
        "from 1850 to 1870",
        url: "https://doi.org/10.5479/si.00810282.294"
      }
      super
    end
  end
end
