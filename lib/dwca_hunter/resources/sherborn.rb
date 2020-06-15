# frozen_string_literal: true

module DwcaHunter
  class ResourceSherborn < DwcaHunter::Resource
    def initialize(opts = {})
      @command = "sherborn"
      @title = "Index Animalium"
      @url = "https://uofi.box.com/shared/static/kj8a26a3bcrraa4kccoyz5jr5uqrqoe6.csv"
      @UUID = "05ad6ca2-fc37-47f4-983a-72e535420e28"
      @download_path = File.join(Dir.tmpdir,
                                 "dwca_hunter",
                                 "sherborn",
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
      puts "Downloading."
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
      dupes = {}
      @names_index = {}
      file = CSV.open(File.join(@download_dir, "data.csv"),
                      headers: false, col_sep: "\t")
      file.each_with_index do |row, i|
        next if dupes.key?(row[1])

        dupes[row[1]] = true
        taxon_id = row[0]
        name_string = row[1]

        @names << { taxon_id: taxon_id,
                    name_string: name_string }
        puts "Processed %s names" % i if i % 10_000 == 0
      end
    end

    def generate_dwca
      DwcaHunter.logger_write(object_id,
                              "Creating DarwinCore Archive file")
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
                "http://rs.tdwg.org/dwc/terms/scientificName",
                "http://rs.tdwg.org/dwc/terms/nomenclaturalCode"]]
      @names.each do |n|
        @core << [n[:taxon_id], n[:name_string], "ICZN"]
      end

      @eml = {
        id: @uuid,
        title: @title,
        authors: [
          { first_name: "Charles Davies",
            last_name: "Sherborn" }
        ],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
            email: "dmozzherin@gmail.com" }
        ],
        abstract: "Index Animalium is a monumental work that covers " \
                  "400 000 zoological names registered by science " \
                  "between 1758 and 1850",
        url: @url
      }
      super
    end
  end
end
