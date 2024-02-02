# frozen_string_literal: true

# rubocop:disable all
module DwcaHunter
  class ResourceWoRMS < DwcaHunter::Resource
    def initialize() # opts = { download: false, unpack: false })
      @command = "worms"
      @title = "World Register of Marine Species"
      # Download using sf33 machine
      # Put to box.com to get the same download link
      @url = "https://uofi.box.com/shared/static/s5smmpz9o36t08pimaw5exp74h5q8aag.zip"
      @UUID = "bf077d91-673a-4be4-8af9-76db45d07e98"
      @download_path = File.join(Dir.tmpdir,
                                 "dwca_hunter",
                                 "worms",
                                 "data.zip")
      @synonyms = []
      @names = []
      @vernaculars = []
      @extensions = []
      @vernaculars_hash = {}
      super(opts)
    end

    def download
      `curl -s -L #{@url} -o #{@download_path}`
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
      collect_vernaculars
    end
    
    def collect_vernaculars
      file = CSV.open(File.join(@download_dir, "vernacularname.txt"),
                      headers: true, col_sep: "\t", quote_char: "\b")
      file.each_with_index do |row, i|
        taxon_id = row["taxonID"].strip
        vern_name = row["vernacularName"].strip
        lang = row["language"].to_s.strip 
        @vernaculars << { taxon_id: taxon_id, vern: vern_name, lang: lang }
        puts "Processed %s vernaculars" % i if i % 10_000 == 0
      end 
      
    end

    def collect_names
      @names_index = {}
      file = CSV.open(File.join(@download_dir, "taxon.txt"),
                      headers: true, col_sep: "\t", quote_char: "\b")
      file.each_with_index do |row, i|
        taxon_id = row["taxonID"].strip
        name_string = row["scientificName"].strip
        authors = row["scientificNameAuthorship"].to_s.strip
        rank = row["taxonRank"].to_s.strip
        accepted = row["acceptedNameUsageID"].to_s.strip
        accepted = taxon_id if accepted.empty?
        status = row["taxonomicStatus"].to_s.strip
        code = row["nomenclaturalCode"].to_s.strip
        kingdom = row["kingdom"].to_s.strip
        phyllum = row["phylum"].to_s.strip
        klass = row["class"].to_s.strip
        order = row["order"].to_s.strip
        family = row["family"].to_s.strip
        genus = row["genus"].to_s.strip



        @names << { taxon_id: taxon_id,
                    name_string: "#{name_string} #{authors}".strip,
                    rank: rank,
                    kingdom: kingdom,
                    phyllum: phyllum,
                    class: klass,
                    order: order,
                    family: family,
                    genus: genus,
                    status: status,
                    accepted: accepted,
                    code: code }
        puts "Processed %s names" % i if i % 10_000 == 0
      end
    end

    def generate_dwca
      DwcaHunter.logger_write(object_id,
                              "Creating DarwinCore Archive file")
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
                "http://rs.tdwg.org/dwc/terms/acceptedNameUsageID",
                "http://rs.tdwg.org/dwc/terms/scientificName",
                "http://rs.tdwg.org/dwc/terms/taxonRank",
                "http://rs.tdwg.org/dwc/terms/kingdom",
                "http://rs.tdwg.org/dwc/terms/phylum",
                "http://rs.tdwg.org/dwc/terms/class",
                "http://rs.tdwg.org/dwc/terms/order",
                "http://rs.tdwg.org/dwc/terms/family",
                "http://rs.tdwg.org/dwc/terms/genus",
                "http://rs.tdwg.org/dwc/terms/nomenclaturalStatus",
                "http://rs.tdwg.org/dwc/terms/nomenclaturalCode"]]
      @names.each do |n|
        @core << [n[:taxon_id], n[:accepted], n[:name_string], n[:rank],
                  n[:kingdom], n[:phyllum], n[:class], n[:order],
                  n[:family], n[:genus], n[:status], n[:code]]
      end

      @extensions << {
        data: [[
          "http://rs.tdwg.org/dwc/terms/taxonID",
          "http://rs.tdwg.org/dwc/terms/vernacularName",
          "http://rs.tdwg.org/dwc/terms/language"
        ]],
        file_name: "vernacular_names.txt",
        row_type: "http://rs.gbif.org/terms/1.0/VernacularName"
      }
      
      @vernaculars.each do |v|
        @extensions[-1][:data] << [v[:taxon_id], v[:vern], v[:lang]]
      end

      @vernaculars.each do |v|
        @extensions[-1][:data] << [v[:taxon_id], v[:vern]]
      end
      @eml = {
        id: "http://dx.doi.org/10.14284/170",
        title: @title,
        authors: [],
        metadata_providers: [
          { 
            organization_name: "WoRMS Data Management Team (DMT)",
            email: "info@marinespecies.org",
            city: "Ostend",
            postal_code: "8400",
            country: "BE",
            online_url: "https://www.marinespecies.org"
          }
        ],
        abstract: "An authoritative classification and catalogue of marine names",
        url: "https://marinespecies.org/"
      }
      super
    end
  end
end
