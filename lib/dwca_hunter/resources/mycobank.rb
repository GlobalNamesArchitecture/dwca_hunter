# frozen_string_literal: true

module DwcaHunter
  class ResourceMycoBank < DwcaHunter::Resource
    def initialize(opts = { download: true, unpack: true })
      @command = "mycobank"
      @title = "MycoBank"
      # Download https://www.mycobank.org/images/MBList.zip, open in
      # LibreOffice, save csv file, upload it to box.com
      @url = "https://uofi.box.com/shared/static/4pcbwj40ut17ejemdzxwpio1jmxccwwc.csv"
      @UUID = "b0ac4f6f-fc56-41b4-ad69-6af30a881e7e"
      @download_path = File.join(Dir.tmpdir,
                                 "dwca_hunter",
                                 "mycobank",
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

    def classification(s)
      s.split(",").map(&:strip)[0..5]
    end

    def collect_names
      @names_index = {}
      file = CSV.open(File.join(@download_dir, "data.csv"),
                      headers: true)
      file.each_with_index do |row, i|
        taxon_id = row["ID"].strip
        name_string = row["Taxon name"].strip
        authors = row["Authors"]
        authors = authors.nil? ? "" : authors.strip
        rank = row["Rank.Rank name"].strip
        reference = row["Current name"]
        reference = reference.nil? ? "" : reference.strip
        year = row["Year of effective publication"]
        status = row["Name status"].strip
        code = "ICN"

        @names << { taxon_id:,
                    name_string: "#{name_string} #{authors}".strip,
                    rank:,
                    status:,
                    year:,
                    reference:,
                    code: }
        puts "Processed %s names" % i if i % 10_000 == 0
      end
    end

    def generate_dwca
      DwcaHunter.logger_write(object_id,
                              "Creating DarwinCore Archive file")
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
                "http://rs.tdwg.org/dwc/terms/scientificName",
                "http://rs.tdwg.org/dwc/terms/taxonRank",
                "http://rs.tdwg.org/dwc/terms/nomenclaturalStatus",
                "http://rs.tdwg.org/dwc/terms/namePublishedInYear",
                "http://rs.tdwg.org/dwc/terms/namePublishedIn",
                "http://rs.tdwg.org/dwc/terms/nomenclaturalCode"]]
      @names.each do |n|
        @core << [n[:taxon_id], n[:name_string], n[:rank],
                  n[:status], n[:year], n[:reference], n[:code]]
      end

      @eml = {
        id: @uuid,
        title: @title,
        authors: [],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
            email: "dmozzherin@gmail.com" }
        ],
        abstract: "MycoBank is an on-line database aimed as a service " \
        "to the mycological and scientific community by documenting " \
        "mycological nomenclatural novelties (new names and combinations) " \
        "and associated data. Westerijk Fungal Biodiversity Institute.",
        url: "https://www.mycobank.org/"
      }
      super
    end
  end
end
