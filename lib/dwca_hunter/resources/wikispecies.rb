# frozen_string_literal: true

module DwcaHunter
  # Wikispecies source
  class ResourceWikispecies < DwcaHunter::Resource
    def initialize(opts = { download: true, unpack: true })
      @wikisp_path = File.join(Dir.tmpdir, "dwca_hunter", "wikispecies")
      @problems_file = File.open(File.join(Dir.tmpdir, "problems.txt"), "w:utf-8")
      @command = "wikispecies"
      @title = "Wikispecies"
      @url = "https://dumps.wikimedia.org/specieswiki/latest/" \
             "specieswiki-latest-pages-articles.xml.bz2"
      @url = opts[:url] if opts[:url]
      @uuid = "68923690-0727-473c-b7c5-2ae9e601e3fd"
      @download_path = File.join(@wikisp_path, "data.xml.bz2")
      @data = []
      @templates = {}
      @taxon_ids = {}
      @tree = {}
      @paths = {}
      @extensions = []
      @parser = Biodiversity::Parser
      @re = {
        page_start: /^\s*<page>\s*$/,
        page_end: %r{^\s*</page>\s*$},
        template: /Template:/i,
        template_link: /\{\{([^}]*)\}\}/,
        vernacular_names: /\{\{\s*VN\s*\|([^}]+)\}\}/i
      }
      super(opts)
    end

    def download
      puts "Downloading from the source"
      `curl -L #{@url} -o #{@download_path}`
    end

    def unpack
      unpack_bz2
    end

    def make_dwca
      enrich_data
      generate_dwca
    end

    private

    def enrich_data
      DwcaHunter.logger_write(object_id,
                              "Extracting data from xml file...")
      Dir.chdir(@download_dir)
      f = open("data.xml", "r:utf-8")
      page_on = false
      page = ""
      page_num = 0
      f.each do |l|
        if l.match(@re[:page_start])
          page += l
          page_on = true
        elsif page_on
          page += l
          if l.match(@re[:page_end])
            page_on = false
            page_xml = Nokogiri::XML.parse(page)
            if template?(page_xml)
              process_template(page_xml)
            else
              process_species(page_xml)
            end
            page_num += 1
            if (page_num % BATCH_SIZE).zero?
              DwcaHunter.logger_write(object_id,
                                      "Traversed #{page_num} pages")
            end
            page = ""
            @page_title = nil
            @page_id = nil
          end
        end
      end
      DwcaHunter.logger_write(object_id,
                              "Extracted total %s pages" % page_num)
      f.close
    end

    def process_template(x)
      name = page_title(x).gsub!(@re[:template], "").strip
      text = x.xpath("//text").text.strip
      parent_name = text.match(@re[:template_link])
      if parent_name
        return if parent_name[1].match(/\#if/)

        list = parent_name[1].split("|")
        parent_name = if list.size == 1
                        list[0]
                      elsif list[0].match(/Taxonav/i)
                        list[1]
                      else
                        list[0]
                      end
      end
      name.gsub!(/_/, " ")
      parent_name&.gsub!(/_/, " ")
      @templates[name] = { parentName: parent_name, id: page_id(x) }
    end

    def process_species(x)
      return if page_title(x).match(/Wikispecies/i)

      items = find_species_components(x)
      return unless items

      @data << {
        taxonId: page_id(x),
        canonicalForm: page_title(x),
        scientificName: page_title(x),
        classificationPath: [],
        vernacularNames: []
      }
      get_full_scientific_name(items)
      get_vernacular_names(items)
    end

    def get_full_scientific_name(items)
      name_ary = items["{{int:name}}"]

      if name_ary.nil? || name_ary.empty?
        @problems_file.write("%s\n" % @data[-1][:canonicalForm])
        return
      end

      name = name_ary[0]
      name = parse_name(name, @data[-1])
      return unless name != ""

      @data[-1][:scientificName] = name
    end

    def get_vernacular_names(items)
      vern = items["{{int:vernacular names}}"]
      return unless vern.is_a?(Array) && vern.size.positive?

      vn_string = vern.join("")
      vn = vn_string.match(@re[:vernacular_names])
      return unless vn

      vn_list = vn[1].strip.split("|")
      vnames = []
      vn_list.each do |item|
        language, name = item.split("=").map(&:strip)
        next unless language && name && language.size < 4 && name.valid_encoding?

        vnames << {
          name: name,
          language: language
        }
      end

      @data[-1][:vernacularNames] = vnames
    end

    def init_classification_path(items)
      # ignore non-template links
      items["taxonavigation"]&.each do |line|
        line.gsub!(/\[\[.*\]\]/, "") # ignore non-template links
        next unless template_link = line.match(@re[:template_link])

        template_link = template_link[1].
                        strip.gsub(/Template:/, "").gsub(/_/, " ")
        unless template_link.match(/\|/)
          @data[-1][:classificationPath] << template_link
          break
        end
      end
    end

    def find_species_components(x)
      items = get_items(x.xpath("//text").text)
      is_taxon_item = items.key?("{{int:name}}") &&
                      items.key?("{{int:taxonavigation}}")
      return nil unless is_taxon_item

      items
    end

    def get_items(txt)
      item_on = false
      items = {}
      current_item = nil
      txt.split("\n").each do |l|
        item = l.match(/=+([^=]+)=+/)
        if item
          current_item = item[1].strip.downcase
          items[current_item] = []
        elsif current_item && !l.empty?
          items[current_item] << l
        end
      end
      items
    end

    def page_title(x)
      @page_title ||= x.xpath("//title").first.text
    end

    def page_id(x)
      @page_id ||= x.xpath("//id").first.text
    end

    def template?(page_xml)
      !!page_title(page_xml).match(@re[:template])
    end

    def parse_name(name_string, taxa)
      name_string.gsub!("BASEPAGENAME", taxa[:canonicalForm])
      name_string = name_string.strip
      old_l = name_string.dup
      name_string.gsub!(/^\*\s*/, "")
      name_string.gsub!(/\[\[([^\]]+\|)?([^\]]*)\]\]/, '\2')
      name_string.gsub!(/\{\{([^}]+\|)?([^}]*)\}\}/, '\2')
      name_string.gsub!(/'{2,}/, " ")
      name_string.gsub!(/"{2,}/, " ")
      name_string.gsub!(/:\s*\d.*$/, "")
      name_string.gsub!(/,\s*\[RSD\]/i, "")
      name_string.gsub!(/^\s*†\s*/, "")
      name_string.gsub!(/(:\s*)?\[http:[^\]]+\]/, "")
      # name_string = DwcaHunter::XML.unescape(name_string)
      name_string.gsub!(/<nowiki>.*$/, "")
      name_string.gsub!(%r{<br\s*/?\s*>}, "")
      name_string.gsub!(/^\s*&dagger;\s*/, "")
      name_string.gsub!(/&nbsp;/, " ")
      name_string.gsub!(/\s+/, " ")
      res = name_string.strip
      parsed = @parser.parse(res, simple: true)
      return "" unless %w[1 2].include?(parsed[:quality])

      res
    end

    def generate_dwca
      DwcaHunter.logger_write(object_id,
                              "Creating DarwinCore Archive file")
      @core = [
        ["http://rs.tdwg.org/dwc/terms/taxonID",
         "http://rs.tdwg.org/dwc/terms/scientificName",
         "http://globalnames.org/terms/canonicalForm",
         "http://purl.org/dc/terms/source"]
      ]
      DwcaHunter.logger_write(object_id, "Assembling Core Data")
      count = 0
      @data.map do |d|
        count += 1
        if (count % BATCH_SIZE).zero?
          DwcaHunter.logger_write(object_id,
                                  "Traversing %s core data record" % count)
        end
        taxon_id = begin
          (if d[:classificationPath].empty?
             d[:taxonId]
           else
             @templates[d[:classificationPath].
                                           last][:id]
           end)
        rescue StandardError
          d[:taxonId]
        end
        @taxon_ids[d[:taxonId]] = taxon_id
        parentNameUsageId = begin
          (@templates[d[:classificationPath][-2]][:id] if d[:classificationPath].size > 1)
        rescue StandardError
          nil
        end
        url = "http://species.wikimedia.org/wiki/#{CGI.escape(d[:canonicalForm].gsub(' ', '_'))}"
        path = d[:classificationPath]
        path.pop if path[-1] == d[:canonicalForm]
        canonical_form = d[:canonicalForm].gsub(/\(.*\)\s*$/, "").strip
        scientific_name = if d[:scientificName] == d[:canonicalForm]
                            canonical_form
                          else
                            d[:scientificName]
                          end
        @core << [taxon_id,
                  scientific_name,
                  canonical_form,
                  url]
      end
      @extensions << { data: [[
        "http://rs.tdwg.org/dwc/terms/TaxonID",
        "http://rs.tdwg.org/dwc/terms/vernacularName",
        "http://purl.org/dc/terms/language"
      ]], file_name: "vernacular_names.txt" }
      DwcaHunter.logger_write(object_id,
                              "Creating verncaular name extension for DarwinCore Archive file")
      count = 0
      @data.each do |d|
        count += 1
        if (count % BATCH_SIZE).zero?
          DwcaHunter.logger_write(object_id,
                                  "Traversing %s extension data record" % count)
        end
        d[:vernacularNames].each do |vn|
          taxon_id = @taxon_ids[d[:taxonId]] || nil
          @extensions[-1][:data] << [taxon_id, vn[:name], vn[:language]] if taxon_id
        end
      end
      @eml = {
        id: @uuid,
        title: @title,
        license: "http://creativecommons.org/licenses/by-sa/3.0/",
        authors: [
          { first_name: "Stephen",
            last_name: "Thorpe",
            email: "stephen_thorpe@yahoo.co.nz",
            url: "http://species.wikimedia.org/wiki/Main_Page" }
        ],
        abstract: "The free species directory that anyone can edit.",
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
            email: "dmozzherin@mbl.edu" }
        ],
        url: "http://species.wikimedia.org/wiki/Main_Page"
      }
      super
    end
  end
end
