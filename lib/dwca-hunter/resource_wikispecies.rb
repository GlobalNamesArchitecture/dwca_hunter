# encoding: utf-8
class DwcaHunter
  class ResourceWikispecies < DwcaHunter::Resource
    def initialize(opts = {})
      @problems_file = open('problems.txt', 'w:utf-8')
      @title = "Wikispecies"
      @url = "http://dumps.wikimedia.org/specieswiki/latest/specieswiki-latest-pages-articles.xml.bz2"
      @url = opts[:url] if opts[:url]
      @uuid = "68923690-0727-473c-b7c5-2ae9e601e3fd"
      @download_path = File.join(DEFAULT_TMP_DIR, "dwca_hunter", "wikispecies", "data.xml.bz2")
      @data = []
      @templates = {}
      @taxon_ids = {}
      @tree = {}
      @paths = {}
      @extensions = []
      @re = {
        :page_start => /^\s*\<page\>\s*$/,
        :page_end => /^\s*\<\/page\>\s*$/,
        :template => /Template:/i,
        :template_link => /\{\{([^\}]*)\}\}/,
        :vernacular_names => /\{\{\s*VN\s*\|([^\}]+)\}\}/i
      }
      super(opts)
    end

    def unpack
      unpack_bz2
    end

    def make_dwca
      enrich_data
      extend_classification
      generate_dwca
    end

  private

    def enrich_data
      DwcaHunter::logger_write(self.object_id, "Extracting data from xml file...")
      Dir.chdir(@download_dir)
      f = open('data.xml', 'r:utf-8')
      page_on = false
      page = ""
      page_num = 0
      f.each do |l|
        if l.match(@re[:page_start])
          page << l
          page_on = true
        elsif page_on
          page << l
          if l.match(@re[:page_end])
            page_on = false
            page_xml = Nokogiri::XML.parse(page)
            template?(page_xml) ? process_template(page_xml) : process_species(page_xml)
            page_num += 1
            DwcaHunter::logger_write(self.object_id, "Traversed %s pages" % page_num) if page_num % BATCH_SIZE == 0
            page = ""
            @title = nil
          end
        end
      end
      DwcaHunter::logger_write(self.object_id, "Extracted total %s pages" % page_num)
      f.close
    end

    def extend_classification
      DwcaHunter::logger_write(self.object_id, "Extending classifications")
      @data.each_with_index do |d, i|
        unless d[:classificationPath].empty?
          n = 50
          while n > 0
            n -= 1
            if n == 0
              d[:classificationPath] = []
              break
            end
            parent = @templates[d[:classificationPath].first]
            if parent
              d[:classificationPath].unshift(parent[:parentName])
            else
              update_tree(d[:classificationPath])
              break
            end
          end
        end
        # d[:classificationPath] = d[:classificationPath].join("|").gsub("Main Page", "Life")
        DwcaHunter::logger_write(self.object_id, "Extended %s classifications" % i) if i % BATCH_SIZE == 0 && i > 0
      end
    end

    def update_tree(path)
      path = path.dup
      return if @paths.has_key?(path.join("|"))
      (0...path.size).each do |i|
        subpath = path[0..i]
        subpath_string = subpath.join("|")
        next if @paths.has_key?(subpath_string)
        name = subpath.pop
        tree_element = subpath.inject(@tree) { |res, n| res[n] }
        tree_element[name] = {}
        @paths[subpath_string] = 1
      end
    end

    def process_template(x)
      name = title(x).gsub!(@re[:template], '').strip
      text = x.xpath('//text').text.strip
      parent_name = text.match(@re[:template_link])
      if parent_name
        return if parent_name[1].match(/\#if/)
        list = parent_name[1].split("|")
        if list.size == 1
          parent_name = list[0]
        elsif list[0].match /Taxonav/i
          parent_name = list[1]
        else
          parent_name = list[0]
        end
      end
      @templates[name] = { parentName: parent_name, id: x.xpath('//id').text }
    end

    def process_species(x)
      return if title(x).match(/Wikispecies/i)
      items = find_species_components(x)
      if items
        @data << { :taxonId => x.xpath('//id').text, :canonicalForm => title(x), :scientificName => title(x), :classificationPath => [], :vernacularNames => [] }
        get_full_scientific_name(items)
        get_vernacular_names(items)
        init_classification_path(items)
      end
    end

    def get_full_scientific_name(items)
      if items['name'] 
        if name = items['name'][0]
          @data[-1][:scientificName] = parse_name(name, @data[-1])
        else
          @problems_file.write("%s\n" % @data[-1][:canonicalForm])
        end
      end
    end

    def get_vernacular_names(items)
      if items['vernacular names'] && items['vernacular names'].size > 0
        vn_string = items['vernacular names'].join("")
        vn = vn_string.match(@re[:vernacular_names])
        if vn
          vn_list = vn[1].strip.split("|")
          vnames = []
          vn_list.each do |item|
            language, name = item.split("=").map { |x| x.strip }
            vnames << { name: name, language: language } if language && name && language.size < 4 && name.valid_encoding?
          end
          @data[-1][:vernacularNames] = vnames
        end
      end
    end

    def init_classification_path(items)
      if items['taxonavigation']
        items['taxonavigation'].each do |i|
          if link = i.match(@re[:template_link])
            link = link[1].strip
            if !link.match(/\|/)
              @data[-1][:classificationPath] << link
              break
            end
          end
        end
      end
    end

    def find_species_components(x)
      items = get_items(x.xpath('//text').text)
      return nil unless items.has_key?('name') || items.has_key?('taxonavigation')
      items
    end

    def get_items(txt)
      item_on = false
      items = {}
      current_item = nil
      txt.split("\n").each do |l| 
        item =  l.match(/[\=]+([^\=]+)[\=]+/)
        if item
          current_item = item[1].strip.downcase
          items[current_item] = []
        elsif current_item && !l.empty?
          items[current_item] << l
        end
      end
      items
    end

    def title(x)
      @title ||= x.xpath('//title').text
    end

    def template?(page_xml)
      !!title(page_xml).match(@re[:template])
    end

    def parse_name(name_string, taxa)
      name_string.gsub!('BASEPAGENAME', taxa[:canonicalForm])
      name_string = name_string.strip
      old_l = name_string.dup
      name_string.gsub! /^\*\s*/, ''
      name_string.gsub!(/\[\[([^\]]+\|)?([^\]]*)\]\]/, '\2')
      name_string.gsub!(/\{\{([^\}]+\|)?([^\}]*)\}\}/, '\2')
      name_string.gsub!(/[']{2,}/, ' ')
      name_string.gsub!(/["]{2,}/, ' ')
      name_string.gsub!(/\:\s*\d.*$/, '')
      name_string.gsub!(/,\s*\[RSD\]/i, '')
      name_string.gsub!(/^\s*†\s*/, '')
      name_string.gsub!(/(:\s*)?\[http:[^\]]+\]/, '')
      # name_string = DwcaHunter::XML.unescape(name_string)
      name_string.gsub!(/\<nowiki\>.*$/, '')
      name_string.gsub!(/\<br\s*[\/]?\s*\>/, '')
      name_string.gsub!(/^\s*\&dagger;\s*/, '')
      name_string.gsub!(/&nbsp;/, ' ')
      name_string.gsub!(/\s+/, ' ')
      name_string = name_string.strip
      # puts "%s---%s" % [name_string, old_l]
      return name_string
    end

    def generate_dwca
      DwcaHunter::logger_write(self.object_id, "Creating DarwinCore Archive file")
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID", "http://rs.tdwg.org/dwc/terms/scientificName", "http://rs.tdwg.org/dwc/terms/parentNameUsageID", "http://globalnames.org/terms/canonicalForm", "http://globalnames.org/terms/classificationPath"]]
      DwcaHunter::logger_write(self.object_id, "Assembling Core Data")
      count = 0
      @data.map do |d| 
        count += 1
        DwcaHunter::logger_write(self.object_id, "Traversing %s core data record" % count) if count % BATCH_SIZE == 0
        taxon_id = (d[:classificationPath].empty? ? d[:taxonId] : @templates[d[:classificationPath].last][:id]) rescue d[:taxonId]
        @taxon_ids[d[:taxonId]] = taxon_id
        parentNameUsageId = (d[:classificationPath].size > 1 ? @templates[d[:classificationPath][-2]][:id] : nil) rescue nil
        @core << [taxon_id, d[:scientificName], parentNameUsageId, d[:canonicalForm], d[:classificationPath].join("|")]
      end
      @extensions << { data: [[
        "http://rs.tdwg.org/dwc/terms/TaxonID",
        "http://rs.tdwg.org/dwc/terms/vernacularName",
        "http://purl.org/dc/terms/language"
      ]], :file_name => "vernacular_names.txt" }
      DwcaHunter::logger_write(self.object_id, "Creating verncaular name extension for DarwinCore Archive file")
      count = 0
      @data.each do |d|
        count += 1
        DwcaHunter::logger_write(self.object_id, "Traversing %s extension data record" % count) if count % BATCH_SIZE == 0
        d[:vernacularNames].each do |vn|
          taxon_id = @taxon_ids[d[:taxonId]] ? @taxon_ids[d[:taxonId]] : nil
          @extensions[-1][:data] << [taxon_id, vn[:name], vn[:language]] if taxon_id
        end
      end
      @eml = {
        :id => @uuid,
        :title => @title,
        :license => 'http://creativecommons.org/licenses/by-sa/3.0/',
        :authors => [
          { :first_name => 'Stephen',
            :last_name => 'Thorpe',
            :email => 'stephen_thorpe@yahoo.co.nz', 
            :url => "http://species.wikimedia.org/wiki/Main_Page" }],
        :abstract => 'The free species directory that anyone can edit.',
        :metadata_providers => [
          { :first_name => 'Dmitry',
            :last_name => 'Mozzherin',
            :email => 'dmozzherin@mbl.edu' }],
        :url => 'http://species.wikimedia.org/wiki/Main_Page'
      }
      super
    end

  end
end

