# encoding: utf-8
class DwcaHunter
  class ResourceWoRMS < DwcaHunter::Resource
    def initialize(opts = {})
      @title = "WoRMS"
      @url = "http://content60.eol.org/resources/26.tar.gz"
      @uuid =  "9d27a7ad-2e6a-4597-a79b-23fb3b2f8284"
      @download_path = File.join(DEFAULT_TMP_DIR, "dwca_hunter", "worms", "data.tar.gz")
      @fields = ["dc:identifier", "dc:source", "dwc:Kingdom", "dwc:Phylum", "dwc:Class", "dwc:Order", "dwc:Family", "dwc:Genus", "dwc:ScientificName"]
      @rank = { 1 => "kingdom", 2 => "phylum", 3 => "class", 4 => "order", 5 => "family", 6 => "genus", 7 => "species" }
      @known_paths = {}
      @data = []
      @extensions = []
      @extensions << { data: [[
        "http://rs.tdwg.org/dwc/terms/taxonId",
        "http://rs.tdwg.org/dwc/terms/scientificName"]], 
        file_name: "synonyms.txt" }
      @re = {
        cdata: /\<\!\[CDATA\[(.*)\]\]\>/
      }
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
        "http://purl.org/dc/terms/parentNameUsageID",
        "http://purl.org/dc/terms/source",
        "http://rs.tdwg.org/dwc/terms/acceptedNameUsageID",
        "http://purl.org/dc/terms/scientificName",
        "http://purl.org/dc/terms/taxonRank"]]
      super
    end
    
    def unpack
      unpack_tar
    end
    
    def make_dwca
      collect_data
      make_core_data
      generate_dwca
    end

    private

    def collect_data
      DwcaHunter::logger_write(self.object_id, "Traversing xml file...")
      xml_file = File.join(@download_dir, "26.xml")
      f = open(xml_file, "r:utf-8")
      in_taxon = false
      taxon = nil
      count = 0
      Nokogiri::XML::Reader(f).each do |node|
        if !in_taxon && node.name == "taxon"
          in_taxon = true
          taxon = {}
          @fields.each { |field| taxon[field.to_sym] = nil }
          taxon[:synonyms] = []
        elsif in_taxon && node.name == "taxon"
          in_taxon = false
          @data << taxon
          taxon = nil
          count += 1
          DwcaHunter::logger_write(self.object_id, "Extracted %s taxons" % count) if count % BATCH_SIZE == 0
        elsif in_taxon
          item = node.name.to_sym
          if taxon.has_key?(item) && !taxon[item]
            text = node.inner_xml
            if cdata = text.match(@re[:cdata])
              text = cdata[1]
            else
              text = DwcaHunter::XML.unescape(text)
            end
            taxon[item] = text
          elsif node.name == "synonym" && (cdata = node.inner_xml.match(@re[:cdata]))
            taxon[:synonyms] << cdata[1]
          end
        end
      end
    end

    def get_gn_id(path_string)
      gn_uuid = UUID.create_v5(path_string, GNA_NAMESPACE)
      id = Base64.urlsafe_encode64(gn_uuid.raw_bytes)[0..-3]
      "gn:" + id
    end

    def make_core_data
      DwcaHunter::logger_write(self.object_id, "Creating core data")
      @data.each_with_index do |taxa, i|
        DwcaHunter::logger_write(self.object_id, "Traversing %s species for core" % i) if i % BATCH_SIZE == 0
        path = get_path(taxa)
        parent_id = get_gn_id(path.join("|"))
        @core << [taxa[:"dc:identifier"], parent_id, taxa[:"dc:source"], nil, taxa[:"dwc:ScientificName"], "species"]

        taxa[:synonyms].each do |synonym|
          @extensions[0][:data] << [taxa[:"dc:identifier"], synonym]
        end

        until path.empty?
          path_string = path.join("|")
          unless @known_paths[path_string]
            @known_paths[path_string] = 1
            parent_id = (path.size == 1) ? nil : get_gn_id([path[0..-2]].join("|"))
            id = get_gn_id(path_string)
            @core << [id, parent_id, nil, nil, path[-1], @rank[path.size]]
          end
          path.pop
        end
      end
    end

    def get_path(taxa)
      path = []
      @fields[2..-2].each do |field|
        path << taxa[field.to_sym]
      end
      path
    end

    def generate_dwca
      DwcaHunter::logger_write(self.object_id, "Creating DarwinCore Archive file")
      @eml = {
          :id => @uuid,
          :title => @title,
          :authors => [
            { :email => "info@marinespecies.org",
             :url => "http://www.marinespecies.org" }
          ],
          :metadata_providers => [
            { :first_name => 'Dmitry',
              :last_name => 'Mozzherin',
              :email => 'dmozzherin@gmail.com' }
            ],
          :abstract => "The aim of a World Register of Marine Species (WoRMS) is to provide an authoritative and comprehensive list of names of marine organisms, including information on synonymy. While highest priority goes to valid names, other names in use are included so that this register can serve as a guide to interpret taxonomic literature.",
      }
      super
    end
  end
end

