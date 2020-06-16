# frozen_string_literal: true

module DwcaHunter
  class ResourceION < DwcaHunter::Resource
    def initialize(opts = {})
      @command = "ion"
      @title = "Index to Organism Names"
      @url = "https://uofi.box.com/shared/static/tklh8i6q2kb33g6ki33k6s3is06lo9np.gz"
      @UUID = "1137dfa3-5b8c-487d-b497-dc0938605864"
      @download_path = File.join(Dir.tmpdir,
                                 "dwca_hunter",
                                 "ion",
                                 "data.tar.gz")
      @names = []
      @extensions = []
      super(opts)
    end

    def download
      puts "Downloading cached verion of the file. Ask Rod Page to make new."
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
      collect_names
    end

    def collect_names
      file = CSV.open(File.join(@download_dir, "ion.tsv"),
                      headers: true, col_sep: "\t", quote_char: "щ")
      file.each_with_index do |row, i|
        id = row["id"]
        name_string = row["nameComplete"]
        auth = row["taxonAuthor"]

        @names << { taxon_id: id,
                    name_string: name_string,
                    auth: auth }

        puts "Processed %s names" % i if i % 10_000 == 0
      end
    end

    def generate_dwca
      DwcaHunter.logger_write(object_id,
                              "Creating DarwinCore Archive file")
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
                "http://rs.tdwg.org/dwc/terms/scientificName",
                "http://rs.tdwg.org/dwc/terms/scientificNameAuthorship"]]
      @names.each do |n|
        @core << [n[:taxon_id], n[:name_string], n[:auth]]
      end

      @eml = {
        id: @uuid,
        title: @title,
        authors: [
          { first_name: "Nigel",
            last_name: "Robinson",
            email: "nigel.robinson@thomsonreuters.com" }
        ],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
            email: "dmozzherin@gmail.com" }
        ],
        abstract: "ION contains millions of animal names, both fossil and " \
          "recent, at all taxonomic ranks, reported from the scientific " \
          "literature. (Bacteria, plant and virus names will be added soon)." \
          "\n\n" \
          "These names are derived from premier Clarivate databases: " \
          "Zoological Record®, BIOSIS Previews®, and Biological Abstracts®. " \
          "All names are tied to at least one published article. Together, " \
          "these resources cover every aspect of the life sciences - " \
          "providing names from over 30 million scientific records, " \
          "including approximately ,000 international journals, patents, " \
          "books, and conference proceedings. They provide a powerful " \
          "foundation for the most complete collection of organism names " \
          "available today.",
        url: @url
      }
      super
    end
  end
end
