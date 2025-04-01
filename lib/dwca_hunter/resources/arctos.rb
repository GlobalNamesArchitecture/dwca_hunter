# frozen_string_literal: true

module DwcaHunter
  class ResourceArctos < DwcaHunter::Resource
    def initialize(opts = {})
      @command = "arctos"
      @title = "Arctos"
      # @url = "http://arctos.database.museum/cache/gn_merge.tgz.zip"
      # see issue https://github.com/ArctosDB/arctos/issues/5709
      @url = "https://arctos.database.museum/cache/gn_merge.tgz"
      @UUID = "eea8315d-a244-4625-859a-226675622312"
      @download_path = File.join(Dir.tmpdir,
                                 "dwca_hunter",
                                 "arctos",
                                 "data.tar.gz")
      @synonyms = []
      @names = []
      @vernaculars = []
      @extensions = []
      @synonyms_hash = {}
      @vernaculars_hash = {}
      super(opts)
    end

    def download
      puts "Downloading Arctos file."
      # -k ignores certificates
      # -L allows redirections
      `curl -L -k -s #{@url} -o #{@download_path}`
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
      # collect_vernaculars
      collect_names
    end

    def collect_vernaculars
      file = CSV.open(File.join(@download_dir, "globalnames_commonname.csv"),
                      headers: true)
      file.each_with_index do |row, i|
        canonical = row["scientific_name"]
        vernacular_name_string = row["common_name"]

        if @vernaculars_hash.key?(canonical)
          @vernaculars_hash[canonical] << vernacular_name_string
        else
          @vernaculars_hash[canonical] = [vernacular_name_string]
        end

        puts "Processed #{i} vernaculars" if (i % 100_000).zero?
      end
    end

    def collect_synonyms
      file = CSV.open(File.join(@download_dir, "globalnames_relationships.csv"),
                      headers: true)
      file.each_with_index do |row, i|
        canonical = row["scientific_name"]
        if @synonyms_hash.key?(canonical)
          @synonyms_hash[canonical] <<
            { name_string: row["related_name"], status: row["taxon_relationship"] }
        else
          @synonyms_hash[canonical] = [
            { name_string: row["related_name"], status: row["taxon_relationship"] }
          ]
        end
        puts "Processed #{i} synonyms" if (i % 100_000).zero?
      end
    end

    def collect_names
      @names_index = {}
      file = CSV.open(File.join(@download_dir, "globalnames_classification.csv"),
                      headers: true)

      names = {}
      file.each_with_index do |row, i|
        next if row["term_type"].nil?

        name = row["scientific_name"]
        names[name] = if names.key?(name)
                        names[name].
                          merge({ row["term_type"].to_sym => row["term"] })
                      else
                        { row["term_type"].to_sym => row["term"] }
                      end
        puts "Preprocessed #{i} rows" if (i % 100_000).zero?
      end
      names.each_with_index do |m, i|
        canonical = m[0]
        v = m[1]
        taxon_id = "gn_#{i + 1}"
        res = { taxon_id:,
                name_string: canonical,
                kingdom: v[:kingdom],
                phylum: v[:phylum],
                klass: v[:class],
                order: v[:order],
                family: v[:family],
                genus: v[:genus],
                species: v[:species],
                authors: v[:author_text],
                code: v[:nomenclatural_code] }
        @names << res
        update_vernacular(taxon_id, canonical)
        update_synonym(taxon_id, canonical)
        puts "Processed #{i} names" if (i % 100_000).zero?
      end
    end

    def update_vernacular(taxon_id, canonical)
      return unless @vernaculars_hash.key?(canonical)

      @vernaculars_hash[canonical].each do |vern|
        @vernaculars << { taxon_id:, vern: }
      end
    end

    def update_synonym(taxon_id, canonical)
      return unless @synonyms_hash.key?(canonical)

      @synonyms_hash[canonical].each do |syn|
        @synonyms << { taxon_id:, name_string: syn[:name_string],
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
