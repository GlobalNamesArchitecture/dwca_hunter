# frozen_string_literal: true

module DwcaHunter
  # Official virus data from ICTV.
  class ResourceICTV < DwcaHunter::Resource
    def initialize(opts = { unpack: false })
      @command = "ictv"
      @title = "ICTV Virus Taxonomy"
      @url = "https://uofi.box.com/shared/static/ij1ok0wkm7w3s5t5leysozfi59kircon.csv"
      @UUID = "e090da49-8feb-4e03-aff6-a0aa50c4dc37"
      @download_path = File.join(Dir.tmpdir,
                                 "dwca_hunter",
                                 "ictv",
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
      puts "Downloading cached verion of the file. For update see https://talk.ictvonline.org/taxonomy/."
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

    def local_id(s)
      res = s.split("=")
      return "" if res.size != 2

      res[1]
    end

    def collect_names
      @names_index = {}
      file = CSV.open("data.csv", headers: true)
      file.each_with_index do |row, i|
        local_id = local_id(row["Taxon History URL"])
        kingdom = row["Kingdom"]
        phylum = row["Phylum"]
        klass = row["Class"]
        order = row["Order"]
        family = row["Family"]
        genus = row["Genus"]
        name_string = row["Species"]
        code = "ICTV"
        # 1   Sort
        # 2   Realm
        # 3   Subrealm
        # 4   Kingdom
        # 5   Subkingdom
        # 6   Phylum
        # 7   Subphylum
        # 8   Class
        # 9   Subclass
        # 10  Order
        # 11  Suborder
        # 12  Family
        # 13  Subfamily
        # 14  Genus
        # 15  Subgenus
        # 16  Species
        # 17  Genome Composition
        # 18  Last Change
        # 19  MSL of Last Change
        # 20  Proposal for Last Change
        # 21  Taxon History URL
        taxon_id = "gn_#{i + 1}"
        @names << { taxon_id: taxon_id,
                    local_id: local_id,
                    kingdom: kingdom,
                    phylum: phylum,
                    klass: klass,
                    order: order,
                    family: family,
                    genus: genus,
                    name_string: name_string,
                    code: code }
        puts "Processed #{i} names" if (i % 10_000).zero?
      end
    end

    def generate_dwca
      DwcaHunter.logger_write(object_id,
                              "Creating DarwinCore Archive file")
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
                "http://globalnames.org/terms/localID",
                "http://rs.tdwg.org/dwc/terms/scientificName",
                "http://rs.tdwg.org/dwc/terms/kingdom",
                "http://rs.tdwg.org/dwc/terms/phylum",
                "http://rs.tdwg.org/dwc/terms/class",
                "http://rs.tdwg.org/dwc/terms/order",
                "http://rs.tdwg.org/dwc/terms/family",
                "http://rs.tdwg.org/dwc/terms/genus",
                "http://rs.tdwg.org/dwc/terms/nomenclaturalCode"]]
      @names.each do |n|
        @core << [n[:taxon_id], n[:local_id], n[:name_string],
                  n[:kingdom], n[:phylum], n[:klass], n[:order],
                  n[:family], n[:genus], n[:code]]
      end

      @eml = {
        id: @uuid,
        title: @title,
        authors: [
          { first_name: "ICTV" }
        ],
        metadata_providers: [
          { first_name: "ICTV" }
        ],

        abstract: "The ICTV was created as a committee of the Virology " \
                  "Division of the International Union of Microbiological " \
                  "Societies (IUMS) and is governed by Statutes approved " \
                  "by the Virology Division.",
        url: "https://talk.ictvonline.org/taxonomy/"
      }
      super
    end
  end
end
