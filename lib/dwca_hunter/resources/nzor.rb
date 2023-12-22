require "rest-client"
require "json"

module DwcaHunter
  # Resource for FishBase
  class ResourceNZOR < DwcaHunter::Resource
    attr_reader :title, :abbr
    def initialize(opts = {download: false}) #download: false, unpack: false})
      @command = "nzor"
      @title = "New Zealand Organizm Register"
      @abbr = "NZOR"
      # There is also a backup at box.com
      @url = "https://data.nzor.org.nz/v1/names?page="
      @uuid = "365ee637-7189-4551-a52a-74aa79d3ee2f"
      @download_dir = File.join(Dir.tmpdir, "dwca_hunter", "nzor")
      @download_path = File.join(@download_dir, "nzor.jsonl")
      @data = {sci_names: [], vern_names: []}
      @extensions = []
      super
    end

    def download
      f = File.open(@download_path, 'w:utf-8')
      headers = { accept: :json}
      i = 0
      while
        i += 1
        resp = RestClient.get(@url + i.to_s, headers)
        puts "Processed #{i} pages" if (i % 100).zero?
        sleep(0.1)
        f.write(resp.body)
        f.write("\n")
        begin
          res = JSON.parse(resp.body)
          break if res["names"].size == 0
        rescue JSON::ParserError => e
          puts "Error parsing JSON: #{e.message}"
        end
      end
    end

    def unpack
    end

    def make_dwca
      organize_data
      generate_dwca
    end

    private

    def get_classification(cl)
      res = {
        kingdom: nil,
        phylum: nil,
        klass: nil,
        order: nil,
        family: nil,
        genus: nil,
      }

      cl.each do |e|
        name = e["partialName"]
        case e["rank"]
        when "kingdom"
          res[:kingdom] = name
        when "phylum"
          res[:phylum] = name
        when "class"
          res[:klass] = name
        when "order"
          res[:order] = name
        when "family"
          res[:family] = name
        when "genus"
          res[:genus] = name
        end
      end
      res
    end

    def get_sci_name(n)
      clsf = get_classification(n["classificationHierarchy"])
      res = {
        id: n["nameId"],
        name: n["fullName"],
        rank: n["rank"],
        status: n["status"],
        code: n["governingCode"],
        acceptedNameId: n.dig("acceptedName", "nameId"),
        kingdom: clsf[:kingdom],
        phylum: clsf[:phylum],
        klass: clsf[:klass],
        order: clsf[:order],
        family: clsf[:family],
        genus: clsf[:genus],
      }
      res
    end

    def get_vern_name(n)
      sci_name_id = nil
      apps = nil
      concepts = n["concepts"]
      if !concepts.nil?
        concepts.each do |c|
          a = c["applications"]
          if !a.nil? && a.size > 0
            apps = a
            break
          end
        end
      end
      if apps && apps.size > 0 && apps[0]["type"] == "is vernacular for"
        sci_name_id = apps[0].dig("concept", "name", "nameId")
      end
      
      res = {
        id: n["nameId"],
        name: n["fullName"],
        sci_name_id: sci_name_id,
        language: lang(n["language"]),
      }
      res
    end

    def lang(l)
      case l
      when "English"
        return "en"
      when "Māori"
        return "mi"
      else
        return "nil"
      end
    end

    def organize_data
      DwcaHunter::logger_write(self.object_id,
                               "Organizing data")
      File.readlines(@download_path).each_with_index do |l, idx|
        l_obj = JSON.parse(l)
        l_obj["names"].each do |n|
          klass = n["class"]
          case klass
          when "Scientific Name"
            @data[:sci_names] << get_sci_name(n)
          when "Vernacular Name"
            vn = get_vern_name(n)
            if !vn[:sci_name_id].nil?
              @data[:vern_names] << vn
            else
              puts "bad vernacular"
              puts vn
            end

          else
          end
        end
      end
    end

    def generate_dwca
      DwcaHunter::logger_write(self.object_id,
                               'Creating DarwinCore Archive file')

      core_init
      eml_init
      DwcaHunter::logger_write(self.object_id, 'Assembling Core Data')
      count = 0
      @data[:sci_names].each do |d|
        count += 1
        if count % 10000 == 0
          DwcaHunter::logger_write(self.object_id, "Core row #{count}")
        end
        @core << [d[:name_id], d[:acceptedNameId], d[:name], d[:kingdom],
          d[:phylum], d[:klass], d[:order], d[:family], d[:genus],
          d[:status], d[:rank], d[:code]]
      end
      @data[:vern_names].each do |d|
        @extensions[0][:data] << [d[:sci_name_id], d[:name], d[:language]]
      end
      super
    end

    def eml_init
      @eml = {
        id: @uuid,
        title: @title,
        authors: [],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
          }
        ],
        abstract: "NZOR is an actively maintained compilation of all " \
                  "organism names relevant to New Zealand: indigenous, " \
                  "endemic or exotic species or species not present in " \
                  "New Zealand but of national interest. NZOR is digitally " \
                  "and automatically assembled from a number of taxonomic " \
                  "data providers. It provides a consensus opinion on the " \
                  "preferred name for an organism, any alternative " \
                  "scientific names (synonyms), common and Māori names, " \
                  "relevant literature, and the data provider’s view on " \
                  "the documented presence/absence in New Zealand.",
        url: "https://www.nzor.org.nz/"
      }
    end

    def core_init
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
                "http://rs.tdwg.org/dwc/terms/acceptedNameUsageID",
                "http://rs.tdwg.org/dwc/terms/scientificName",
                "http://rs.tdwg.org/dwc/terms/kingdom",
                "http://rs.tdwg.org/dwc/terms/phylum",
                "http://rs.tdwg.org/dwc/terms/class",
                "http://rs.tdwg.org/dwc/terms/order",
                "http://rs.tdwg.org/dwc/terms/family",
                "http://rs.tdwg.org/dwc/terms/genus",
                "http://rs.tdwg.org/dwc/terms/taxonomicStatus",
                "http://rs.tdwg.org/dwc/terms/taxonRank",
                "http://rs.tdwg.org/dwc/terms/nomenclaturalCode"]]
      @extensions << {
        data: [["http://rs.tdwg.org/dwc/terms/TaxonID",
                "http://rs.tdwg.org/dwc/terms/vernacularName",
                "http://purl.org/dc/terms/language"]],
        file_name: "vernacular_names.txt",
        row_type: "http://rs.gbif.org/terms/1.0/VernacularName" }
    end
  end
end
