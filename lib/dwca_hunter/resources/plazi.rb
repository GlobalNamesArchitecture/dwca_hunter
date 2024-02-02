# frozen_string_literal: true

module DwcaHunter
  # Resource for PLAZI
  class ResourcePLAZI < DwcaHunter::Resource
    attr_reader :title, :abbr

    def initialize(opts = { download: true })
      @command = "plazi"
      @title = "PLAZI treatments"
      @url = "http://tb.plazi.org/GgServer/xml.rss.xml"
      @abbr = "PLAZI"
      @uuid = "68938dc9-b93d-43bc-9d51-5c2a632f136f"
      @download_path = File.join(Dir.tmpdir, "dwca_hunter", "plazi",
                                 "data.xml")
      @data = []
      @extensions = []
      super
    end

    def download
      puts "Downloading from the source"
      `curl -L #{@url} -o #{@download_path}`
    end

    def unpack; end

    def make_dwca
      organize_data
      generate_dwca
    end

    private

    def organize_data
      DwcaHunter.logger_write(object_id,
                              "Harvesting data from XML file")

      data = File.read(@download_path)
      data_xml = Nokogiri::XML.parse(data)
      data_xml.xpath("//item").each do |item|
        name = item_name(item)
        id = item_id(item)
        @data << { scientific_name: name, taxon_id: id }
      end
    end

    def generate_dwca
      DwcaHunter.logger_write(object_id,
                              "Creating DarwinCore Archive file")
      core_init
      eml_init
      DwcaHunter.logger_write(object_id, "Assembling Core Data")
      count = 0
      @data.each do |d|
        count += 1
        DwcaHunter.logger_write(object_id, "Core row #{count}") if (count % 10_000).zero?
        @core << [d[:taxon_id], d[:taxon_id], d[:scientific_name]]
      end
      super
    end

    def eml_init
      @eml = {
        id: @uuid,
        title: @title,
        authors: [],
        metadata_providers: [
          { first_name: "Donald",
            last_name: "Agosti" },
          { first_name: "Guido",
            last_name: "Sautter" }
        ],
        abstract: "Plazi is an association supporting and promoting the " \
                  "development of persistent and openly accessible digital " \
                  "taxonomic literature. ",
        url: "http://plazi.org"
      }
    end

    def core_init
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
                "http://globalnames.org/terms/localID",
                "http://rs.tdwg.org/dwc/terms/scientificName"]]
    end

    def item_name(item)
      name = item.xpath("title").text
      m = name.match(/^(.*)(,[\sa-z.]*)$/)
      name = m[1] unless m.nil?
      wrds = name.split(" ")
      if upcase?(wrds[0])
        wrds[0] = wrds[0].capitalize
        name = wrds.join(" ")
      end
      name
    end

    def item_id(item)
      id = item.xpath("guid").text
      id.gsub(/\.xml$/, "")
    end

    def upcase?(word)
      return false if word.nil?

      lowcase = Regexp.new("\\p{Lower}")
      word.match(lowcase).nil?
    end
  end
end
