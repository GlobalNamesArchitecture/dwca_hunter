# frozen_string_literal: true

module DwcaHunter
  class ResourceDiscLifeBees < DwcaHunter::Resource
    def initialize(opts = { download: true })
      @parser = Biodiversity::Parser
      @command = "dlife-bees"
      @title = "Discover Life Bee Species Guide"
      @url = "https://zenodo.org/record/5738043/files/discoverlife-Anthophila.csv?download=1"
      @UUID = "7911b6d6-9029-496f-b3a7-7e233199c1d7"
      @download_path = File.join(Dir.tmpdir,
        "dwca_hunter",
        "dlife_bees",
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

    def find_csv_file
      Dir.chdir(@download_dir)
      Dir.entries(".").each do |f|
        return f if f[-4..-1] == ".csv"
      end
    end

    def assemble_synonym(row)
      name = row["originalNameCombination"].gsub("_", " ")
      auth = "#{row['authoritySpeciesAuthor']} #{row['aurhoritySpeciesYear']}".
        strip
      name = "#{name} #{auth}".strip
      { taxon_id: row["id"], name_string: name, status: "synonym" }
    end

    def gnid(str)
      "gn-#{GnUUID.uuid(str)}"
    end

    def collect_names
      @names_index = {}
      file = CSV.open(File.join(@download_dir, find_csv_file),
        headers: true)
      file.each do |row|
        taxon_id = gnid(row["providedExternalId"]).to_s.strip
        name_string = row["providedName"].to_s.strip
        next if name_string.empty?
        kingdom, phylum, klass, order, family, genus = ""
        path = row["providedPath"].to_s.strip
        unless path.empty?
          kingdom = "Animalia"
          phylum = "Arthropoda"
          klass = "Insecta"
          order = "Hymenoptera"
          family = path.split("|").map(&:strip)[-2]
          genus = name_string.split(" ")[0]
          rank = row["providedRank"]
        end

        accepted_id = gnid(row["resolvedExternalId"].to_s.strip)
        authorship = row["providedAuthorship"].to_s.strip
        name_string = "#{name_string} #{authorship}" unless authorship.empty?


        @names << {
          taxon_id: taxon_id,
          kingdom: kingdom,
          phylum: phylum,
          klass: klass,
          order: order,
          family: family,
          genus: genus,
          current_id: accepted_id,
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
                "http://rs.tdwg.org/dwc/terms/acceptedNameUsageID",
                "http://rs.tdwg.org/dwc/terms/kingdom",
                "http://rs.tdwg.org/dwc/terms/phylum",
                "http://rs.tdwg.org/dwc/terms/class",
                "http://rs.tdwg.org/dwc/terms/order",
                "http://rs.tdwg.org/dwc/terms/family",
                "http://rs.tdwg.org/dwc/terms/genus",
                "http://rs.tdwg.org/dwc/terms/taxonRank",

                "http://rs.tdwg.org/dwc/terms/nomenclaturalCode"]]
      @names.each do |n|
        @core << [n[:taxon_id], n[:name_string], n[:current_id],
                  n[:kingdom], n[:phylum], n[:klass], n[:order], n[:family],
                  n[:genus], n[:rank], n[:nom_code]]
      end

      @eml = {
        id: @uuid,
        title: @title,
        authors: [
          { first_name: "J.",
            middle_name: "S.",
            last_name: "Ascher" },
          { first_name: "J.",
            last_name: "Pickering" }
        ],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
            email: "dmozzherin@gmail.com" }
        ],
        abstract: "Discover Life bee species guide and world checklist.",
        url: "http://www.discoverlife.org/mp/20q?act=x_checklist&guide=Apoidea_species"
      }
      super
    end
  end
end
