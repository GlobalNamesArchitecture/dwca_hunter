# frozen_string_literal: true

module DwcaHunter
  class ResourceArctos < DwcaHunter::Resource
    def initialize(opts = {})
      @command = "arctos"
      @title = "Arctos"
      @url = "https://www.dropbox.com/s/3rmny5d8cfm9mmp/arctos.tar.gz?dl=1"
      @UUID = "eea8315d-a244-4625-859a-226675622312"
      @download_path = File.join(Dir.tmpdir,
                                 "dwca_hunter",
                                 "arctos",
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
      puts "Downloading cached verion of the file. Ask Arctos to generate new."
      `curl -s -L #{@url} -o #{@download_path}`
    end

    def unpack
      unpack_tar
    end

    def make_dwca
      DwcaHunter.logger_write(object_id, "Extracting data")
      get_names
      generate_dwca
    end

    private

    def get_names
      Dir.chdir(@download_dir)
      collect_synonyms
      collect_vernaculars
      collect_names
    end

    def collect_vernaculars
      file = CSV.open(File.join(@download_dir, "common_name.csv"),
                      headers: true)
      file.each_with_index do |row, i|
        canonical = row["SCIENTIFIC_NAME"]
        vernacular_name_string = row["COMMON_NAME"]

        if @vernaculars_hash.key?(canonical)
          @vernaculars_hash[canonical] << vernacular_name_string
        else
          @vernaculars_hash[canonical] = [vernacular_name_string]
        end

        puts "Processed %s vernaculars" % i if i % 10_000 == 0
      end
    end

    def collect_synonyms
      file = CSV.open(File.join(@download_dir, "relationships.csv"),
                      headers: true)
      file.each_with_index do |row, i|
        canonical = row["scientific_name"]
        if @synonyms_hash.key?(canonical)
          @synonyms_hash[canonical] <<
            { name_string: row["related_name"], status: row["TAXON_RELATIONSHIP"] }
        else
          @synonyms_hash[canonical] = [
            { name_string: row["related_name"], status: row["TAXON_RELATIONSHIP"] }
          ]
        end
        puts "Processed %s synonyms" % i if i % 10_000 == 0
      end
    end

    def collect_names
      @names_index = {}
      file = CSV.open(File.join(@download_dir, "classification.csv"),
                      headers: true)
      file.each_with_index do |row, i|
        next unless row["display_name"]

        name_string = row["display_name"].gsub(%r{</?i>}, "")
        canonical = row["scientific_name"]
        kingdom = row["kingdom"]
        phylum = row["phylum"]
        klass = row["phylclass"]
        subclass = row["subclass"]
        order = row["phylorder"]
        suborder = row["suborder"]
        superfamily = row["superfamily"]
        family = row["family"]
        subfamily = row["subfamily"]
        tribe = row["tribe"]
        genus = row["genus"]
        subgenus = row["subgenus"]
        species = row["species"]
        subspecies = row["subspecies"]
        code = row["nomenclatural_code"]

        taxon_id = "ARCT_#{i + 1}"
        @names << { taxon_id: taxon_id,
                    name_string: name_string,
                    kingdom: kingdom,
                    phylum: phylum,
                    klass: klass,
                    order: order,
                    family: family,
                    genus: genus,
                    code: code }

        update_vernacular(taxon_id, canonical)
        update_synonym(taxon_id, canonical)
        puts "Processed %s names" % i if i % 10_000 == 0
      end
    end

    def update_vernacular(taxon_id, canonical)
      return unless @vernaculars_hash.key?(canonical)

      @vernaculars_hash[canonical].each do |vern|
        @vernaculars << { taxon_id: taxon_id, vern: vern }
      end
    end

    def update_synonym(taxon_id, canonical)
      return unless @synonyms_hash.key?(canonical)

      @synonyms_hash[canonical].each do |syn|
        @synonyms << { taxon_id: taxon_id, name_string: syn[:name_string],
                       status: syn[:status] }
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
          "http://rs.tdwg.org/dwc/terms/vernacularName"
        ]],
        file_name: "vernacular_names.txt",
        row_type: "http://rs.gbif.org/terms/1.0/VernacularName"
      }

      @vernaculars.each do |v|
        @extensions[-1][:data] << [v[:taxon_id], v[:vern]]
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
          { email: "dustymc at gmail dot com" }
        ],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
            email: "dmozzherin@gmail.com" }
        ],
        abstract: "Arctos is an ongoing effort to integrate access to specimen data, collection-management tools, and external resources on the internet.",
        url: @url
      }
      super
    end
  end
end
