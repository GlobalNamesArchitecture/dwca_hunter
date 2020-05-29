# frozen_string_literal: true

module DwcaHunter
  class ResourceAOS < DwcaHunter::Resource
    def initialize(opts = {})
      @command = "aos-birds"
      @title = "American Ornithological Society"
      @url = "http://checklist.americanornithology.org/taxa.csv"
      @UUID = "91d38806-8435-479f-a18d-705e5cb0767c"
      @download_path = File.join(Dir.tmpdir,
                                 "dwca_hunter",
                                 "aos",
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
      puts "Downloading csv from remote"
      `curl -s -L #{@url} -o #{@download_path}`
    end

    def unpack; end

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

    def collect_names
      @names_index = {}
      file = CSV.open(File.join(@download_dir, "data.csv"),
                      headers: true)
      file.each_with_index do |row, _i|
        taxon_id = row["id"]
        name_string = row["species"]
        kingdom = "Animalia"
        phylum = "Chordata"
        klass = "Aves"
        order = row["order"]
        family = row["family"]
        genus = row["genus"]
        code = "ICZN"

        @names << {
          taxon_id: taxon_id,
          name_string: name_string,
          kingdom: kingdom,
          phylum: phylum,
          klass: klass,
          order: order,
          family: family,
          genus: genus,
          code: code
        }
        if row["common_name"].to_s != ""
          @vernaculars << {
            taxon_id: taxon_id,
            vern: row["common_name"],
            lang: "en"
          }
        end
        next unless row["french_name"].to_s != ""

        @vernaculars << {
          taxon_id: taxon_id,
          vern: row["french_name"],
          lang: "fr"
        }
      end
    end

    def generate_dwca
      DwcaHunter.logger_write(object_id,
                              "Creating DarwinCore Archive file")
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
                "http://rs.tdwg.org/dwc/terms/scientificName",
                "http://rs.tdwg.org/dwc/terms/kingdom",
                "http://rs.tdwg.org/dwc/terms/phylum",
                "http://rs.tdwg.org/dwc/terms/class",
                "http://rs.tdwg.org/dwc/terms/order",
                "http://rs.tdwg.org/dwc/terms/family",
                "http://rs.tdwg.org/dwc/terms/genus",
                "http://rs.tdwg.org/dwc/terms/nomenclaturalCode"]]
      @names.each do |n|
        @core << [n[:taxon_id], n[:name_string],
                  n[:kingdom], n[:phylum], n[:klass], n[:order], n[:family],
                  n[:genus], n[:code]]
      end
      @extensions << {
        data: [[
          "http://rs.tdwg.org/dwc/terms/taxonID",
          "http://rs.tdwg.org/dwc/terms/vernacularName",
          "http://purl.org/dc/terms/language"
        ]],
        file_name: "vernacular_names.txt",
        row_type: "http://rs.gbif.org/terms/1.0/VernacularName"
      }

      @vernaculars.each do |v|
        @extensions[-1][:data] << [v[:taxon_id], v[:vern], v[:lang]]
      end
      @eml = {
        id: @uuid,
        title: @title,
        authors: [
          { first_name: "R. T.",
            last_name: "Chesser" }
        ],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
            email: "dmozzherin@gmail.com" }
        ],
        abstract: "The American Ornithological Society's (AOS) Checklist is " \
        "the official source on the taxonomy of birds found in North and " \
        "Middle America, including adjacent islands. This list is produced " \
        "by the North American Classification and Nomenclature Committee " \
        "(NACC) of the AOS.\n\n" \
        "Recommended citation: Chesser, R. T., K. J. Burns, C. Cicero, " \
        "J. L. Dunn, A. W. Kratter, I. J. Lovette, P. C. Rasmussen, " \
        "J. V. Remsen, Jr., D. F. Stotz, and K. Winker. 2019. Check-list " \
        "of North American Birds (online). American Ornithological Society. " \
        "http://checklist.aou.org/taxa",
        url: @url
      }
      super
    end
  end
end
