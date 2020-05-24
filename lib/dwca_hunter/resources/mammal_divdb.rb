# frozen_string_literal: true

module DwcaHunter
  class ResourceMammalDiversityDb < DwcaHunter::Resource
    def initialize(opts = {})
      @command = "mammal-div-db"
      @title = "ASM Mammal Diversity Database"
      @url = "https://mammaldiversity.org/species-account/api.php?q=*"
      @UUID = "94270cdd-5424-4bb1-8324-46ccc5386dc7"
      @download_path = File.join(Dir.tmpdir,
                                 "dwca_hunter",
                                 "mammal-div-db",
                                 "data.json")
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
      @names_index = {}
      decoder = HTMLEntities.new
      data = File.read(File.join(@download_dir, "data.json"))
      data = JSON.parse(data, symbolize_names: true)
      data[:result].each_with_index do |e, _i|
        e = e[1]
        order = e[:dwc][:order].capitalize
        order = nil if order.match(/incertae/)
        family = e[:dwc][:family].capitalize
        family = nil if family.match(/incertae/)
        genus = e[:dwc][:genus].capitalize
        genus = nil if genus.match(/incertae/)
        name = {
          taxon_id: e[:id],
          kingdom: "Animalia",
          phylum: "Chordata",
          klass: "Mammalia",
          order: order,
          family: family,
          genus: genus,
          name_string: "#{e[:dwc][:scientificName]} " \
          "#{e[:dwc][:scientificNameAuthorship][:species]}".strip,
          rank: e[:dwc][:taxonRank],
          status: e[:dwc][:taxonRank],
          code: "ICZN"
        }
        if e[:dwc][:taxonomicStatus] == "accepted"
          @names << name
        else
          @synonyms << name
        end
        vern = e[:dwc][:vernacularName]
        next unless vern.to_s != ""
        vern = decoder.decode(vern)
        vernacular = {
          taxon_id: e[:id],
          vern: vern,
          lang: "en"
        }
        @vernaculars << vernacular
      end
      puts data[:result].size
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
        abstract: "Mammal Diversity Database. 2020. www.mammaldiversity.org. " \
        "American Society of Mammalogists. Accessed 2020-05-24 .",
        url: @url
      }
      super
    end
  end
end
