# frozen_string_literal: true

module DwcaHunter
  class ResourceTropicos < DwcaHunter::Resource
    def initialize(opts = { download: false })
      @parser = Biodiversity::Parser
      @command = "tropicos"
      @title = "Tropicos - Missouri Botanical Garden"
      @url = "https://uofi.box.com/shared/static/r5u6c3f5abvnbc15kylvg3kthj1oe8o8.csv"
      @UUID = "19246ae5-9f47-4aab-b7e2-68e0ba38a2e8"
      @download_path = File.join(Dir.tmpdir,
        "dwca_hunter",
        "tropicos",
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

    def assemble_synonym(row)
      ggenus = row["originalNameCombination"].gsub("_", " ")
      auth = "#{row['authoritySpeciesAuthor']} #{row['aurhoritySpeciesYear']}".
        strip
      genus = "#{genus} #{auth}".strip
      { taxon_id: row["id"], name_string: genus, status: "synonym" }
    end

    def collect_names
      @names_index = {}
      file = CSV.open(@download_path, headers: true)
      file.each do |row|
        id = row["NameID"]
        ggenus = row["FullNameWithAuthors"]
        parent_id = row["NHTID"]
        status = row["NomenclatureStatusName"]
        rank = row["RankName"]

        @names << {
          taxon_id: id,
          parentNameUsageId: parent_id,
          name_string: genus,
          rank: rank,
          nomenclaturalStatus: status,
          nom_code: "ICN"
        }
      end
    end

    def generate_dwca
      DwcaHunter.logger_write(object_id, "Creating DarwinCore Archive file")
      @core = [["http://rs.tdwg.org/dwc/terms/taxonId",
                "http://rs.tdwg.org/dwc/terms/parentNameUsageId",
                "http://rs.tdwg.org/dwc/terms/scientificName",
                "http://rs.tdwg.org/dwc/terms/taxonRank",
                "http://rs.tdwg.org/dwc/terms/nomenclaturalStatus",
                "http://rs.tdwg.org/dwc/terms/nomenclaturalCode"]]
      @names.each do |n|
        @core << [
          n[:taxon_id],
          n[:parentNameUsageId],
          n[:name_string],
          n[:rank],
          n[:nomenclaturalStatus],
          n[:nom_code]
        ]
      end

      @eml = {
        id: @uuid,
        title: @title,
        authors: [
          { first_name: "William",
            last_name: "Ulate" }
        ],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
            email: "dmozzherin@gmail.com" }
        ],
        abstract: "The Tropicos database links over 1.36M scientific names " \
                  "with over 5M specimens and over 893K digital images. " \
                  "The data includes over 159K references from over " \
                  "54.1K publications offered as a free service to the " \
                  "world’s scientific community.",
        url: "https://www.tropicos.org"
      }
      super
    end
  end
end
