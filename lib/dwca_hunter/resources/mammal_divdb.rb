# frozen_string_literal: true

module DwcaHunter
  class ResourceMammalDiversityDb < DwcaHunter::Resource
    def initialize(opts = {})
      @command = "mammal-div-db"
      @title = "ASM Mammal Diversity Database"
      @url = "https://www.mammaldiversity.org/assets/data/MDD.zip"
      @UUID = "94270cdd-5424-4bb1-8324-46ccc5386dc7"
      @download_path = File.join(Dir.tmpdir,
                                 "dwca_hunter",
                                 "mammal-div-db",
                                 "data.zip")
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
      `curl '#{@url}' -H 'User-Agent:' -o #{@download_path}`
    end

    def unpack
      unpack_zip
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

    def find_csv_file
      Dir.chdir(@download_dir)
      Dir.entries(".").each do |f|
        return f if f[-4..-1] == ".csv"
      end
    end

    def assemble_name(row)
      name = row["sciName"].gsub("_", " ")
      auth = "#{row['authoritySpeciesAuthor']} #{row['aurhoritySpeciesYear']}".
        strip
      auth = "(#{auth})" if row["authorityParentheses"] == 1
      rank = "species"
      rank = "subspecies" if (name.split(" ").size > 2)
      name = "#{name} #{auth}".strip
      [rank, name]
    end

    def assemble_synonym(row)
      name = row["originalNameCombination"].gsub("_", " ")
      auth = "#{row['authoritySpeciesAuthor']} #{row['aurhoritySpeciesYear']}".
        strip
      name = "#{name} #{auth}".strip
      { taxon_id: row["id"], name_string: name, status: "synonym" }
    end

    def vernaculars(row)
      id = row["id"]
      res = []
      vern = row["mainCommonName"].to_s
      res << vern  if vern != ""
      verns = row["otherCommonNames"].to_s
      if verns != ""
        verns = verns.split("|")
        res += verns
      end
      res.map do |v|
        { taxon_id: id, vern: v, lang: "en" }
      end
    end

    def collect_names
      @names_index = {}
      file = CSV.open(File.join(@download_dir, find_csv_file),
                      headers: true)
      file.each do |row|
        order = row["order"].to_s.capitalize
        order = nil if order.match(/incertae/) || order.empty?
        family = row["family"].to_s.capitalize
        family = nil if family.match(/incertae/) || family.empty?
        genus = row["genus"].to_s.capitalize
        genus = nil if genus.match(/incertae/) || genus.empty?
        rank, name_string = assemble_name(row)
        @names << {
          taxon_id: row["id"],
          kingdom: "Animalia",
          phylum: "Chordata",
          klass: "Mammalia",
          order: order,
          family: family,
          genus: genus,
          name_string: name_string,
          rank: rank,
          code: "ICZN"
        }
        if row["originalNameCombination"].to_s != ""
          @synonyms << assemble_synonym(row)
        end
        vernaculars(row).each do |vern|
          @vernaculars << vern
        end
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
                "http://rs.tdwg.org/dwc/terms/taxonRank",
                "http://rs.tdwg.org/dwc/terms/nomenclaturalCode"]]
      @names.each do |n|
        @core << [n[:taxon_id], n[:name_string],
                  n[:kingdom], n[:phylum], n[:klass], n[:order], n[:family],
                  n[:genus], n[:rank], n[:code]]
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

      @extensions << {
        data: [[
          "http://rs.tdwg.org/dwc/terms/taxonID",
          "http://rs.tdwg.org/dwc/terms/scientificName",
          "http://rs.tdwg.org/dwc/terms/taxonomicStatus"
        ]],
        file_name: "synonyms.txt"
      }
      @synonyms.each do |s|
        @extensions[-1][:data] << [s[:taxon_id], s[:name_string], s[:status]]
      end
      @eml = {
        id: @uuid,
        title: @title,
        authors: [
          { first_name: "C. J.",
            last_name: "Burgin" },
            { first_name: "J. P.",
              last_name: "Colella" },
              { first_name: "P. L.",
                last_name: "Kahn" },
                { first_name: "N. S.",
                  last_name: "Upham" }
        ],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
            email: "dmozzherin@gmail.com" }
        ],
        abstract: "Mammal Diversity Database. 2021. www.mammaldiversity.org. " \
        "American Society of Mammalogists. Accessed 2021-01-28.", url: @url
      }
      super
      end
    end
  end
