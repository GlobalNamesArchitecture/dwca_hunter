# frozen_string_literal: true

module DwcaHunter
  class ResourceClements < DwcaHunter::Resource
    def initialize(opts = {})
      @command = "clements-ebird"
      @title = "The eBird/Clements Checklist of Birds of the World"
      @url = "https://uofi.box.com/shared/static/o3ekrurtw09025fc1z045auauga5x68y.csv"
      @UUID = "577c0b56-4a3c-4314-8724-14b304f601de"
      @download_path = File.join(Dir.tmpdir,
                                 "dwca_hunter",
                                 "clements",
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
      puts "Downloading cached and modified version of the file."
      puts "Go to https://www.birds.cornell.edu/clementschecklist/download/ " \
        "for updates."
      puts "Download Excel version and convert with LibreOffice to csv."
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

    def collect_names
      @names_index = {}
      file = CSV.open(File.join(@download_dir, "data.csv"),
                      headers: true)
      file.each_with_index do |row, i|
        name_string = row["scientific name"]
        canonical = name_string
        kingdom = "Animalia"
        phylum = "Chordata"
        klass = "Aves"
        order = row["order"]
        family = row["family"]
        code = "ICZN"

        taxon_id = "gn_#{i + 1}"
        @names << { taxon_id: taxon_id,
                    name_string: name_string,
                    kingdom: kingdom,
                    phylum: phylum,
                    klass: klass,
                    order: order,
                    family: family,
                    code: code }

        if row["English name"].to_s != ""
            @vernaculars << {
              taxon_id: taxon_id,
              vern: row["English name"],
              lang: "end"
            }
        end

        puts "Processed %s names" % i if i % 10_000 == 0
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
                "http://rs.tdwg.org/dwc/terms/nomenclaturalCode"]]
      @names.each do |n|
        @core << [n[:taxon_id], n[:name_string],
                  n[:kingdom], n[:phylum], n[:klass], n[:order], n[:family],
                  n[:code]]
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
          { first_name: "G. F.",
            last_name: "Clements"
          },
          { first_name: "T. S.",
            last_name: "Schulenberg"
          },
          { first_name: "M. J.",
            last_name: "Iliff"
          },
          { first_name: "S. M.",
            last_name: "Billerman"
          },
          { first_name: "T. A.",
            last_name: "Fredericks"
          },
          { first_name: "B. L.",
            last_name: "Sullivan"
          },
          { first_name: "C. L.",
            last_name: "Wood"
          },
        ],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
            email: "dmozzherin@gmail.com" }
        ],
        abstract: "The eBird/Clements Checklist of Birds of the World" \
        ": v2019. Downloaded from " \
        "https://www.birds.cornell.edu/clementschecklist/download/",
        url: @url
      }
      super
    end
  end
end
