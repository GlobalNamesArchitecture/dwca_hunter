# frozen_string_literal: true

module DwcaHunter
  class ResourceHowardMoore < DwcaHunter::Resource
    def initialize(opts = {})
      @command = "how-moore-birds"
      @title = "Howard and Moore Complete Checklist of the Birds of the World"
      @url = "https://uofi.box.com/shared/static/m71m541dr5unc41xzg4y51d92b7wiy2k.csv"
      @UUID = "85023fe5-bf2a-486b-bdae-3e61cefd41fd"
      @download_path = File.join(Dir.tmpdir,
                                 "dwca_hunter",
                                 "how-moore-birds",
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
      puts "Downloading cached verion of the file."
      puts "Check https://www.howardandmoore.org/howard-and-moore-database/"
      puts "If there is a more recent edition"
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
      file = CSV.open(File.join(@download_dir, "data.csv"),
                      headers: true)
      file.each_with_index do |row, i|
        kingdom = "Animalia"
        phylum = "Chordata"
        klass = "Aves"
        family = row["FAMILY_NAME"].capitalize
        genus = row["GENERA_NAME"].capitalize
        species = row["SPECIES_NAME"]
        species_au =
          "#{row['species_author']} #{row['species_rec_year']}".strip
        subspecies = row["SUB_SPECIES_NAME"]
        subspecies_au =
          "#{row['subspecies_author']} #{row['subspecies_rec_year']}".strip
        code = "ICZN"

        taxon_id = "gn_#{i + 1}"
        name_string = species
        name_string = if subspecies.to_s == "" ||
                          name_string.include?(subspecies)
                        "#{name_string} #{species_au}".strip
                      else
                        "#{name_string} #{subspecies} #{subspecies_au}".strip
                      end

        @names << { taxon_id: taxon_id,
                    name_string: name_string,
                    kingdom: kingdom,
                    phylum: phylum,
                    klass: klass,
                    family: family,
                    genus: genus,
                    code: code }

        if row["species_english_name"].to_s != ""
          @vernaculars << {
            taxon_id: taxon_id,
            vern: row["species_english_name"],
            lang: "en"
          }
        end
        if row["species_english_name2"].to_s != ""
          @vernaculars << {
            taxon_id: taxon_id,
            vern: row["species_english_name2"],
            lang: "en"
          }
        end

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
                "http://rs.tdwg.org/dwc/terms/family",
                "http://rs.tdwg.org/dwc/terms/genus",
                "http://rs.tdwg.org/dwc/terms/nomenclaturalCode"]]
      @names.each do |n|
        @core << [n[:taxon_id], n[:name_string],
                  n[:kingdom], n[:phylum], n[:klass], n[:family],
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
          {
            last_name: "Christidis"
          }
        ],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
            email: "dmozzherin@gmail.com" }
        ],
        abstract: "Christidis et al. 2018. The Howard and Moore Complete " \
        "Checklist of the Birds of the World, version 4.1 " \
        "(Downloadable checklist). " \
        "Accessed from https://www.howardandmoore.org.",
        url: @url
      }
      super
    end
  end
end
