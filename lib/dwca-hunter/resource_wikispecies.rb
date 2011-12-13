# encoding: utf-8
class DwcaHunter
  class ResourceWikispecies < DwcaHunter::Resource
    def initialize(opts = {})
      @title = "Wikispecies"
      @url = "http://dumps.wikimedia.org/specieswiki/latest/specieswiki-latest-pages-articles.xml.bz2"
      @url = opts[:url] if opts[:url]
      @uuid = "68923690-0727-473c-b7c5-2ae9e601e3fd"
      @download_path = File.join(DEFAULT_TMP_DIR, "dwca_hunter", "wikispecies", "data.xml.bz2")
      super(opts)
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
      DwcaHunter::logger_write(self.object_id, "Extracting data from xml file...")
      page_start = /^\s*\<page\>\s*$/
      title_re = /\<title\>(.*)\<\/title\>/
      id_re = /^\s*\<id\>(.*)\<\/id\>\s*$/
      name_re = /\=\=\s*Name\s*\=\=/i
      classification_re = /\=\=\s*Taxonavigation\s*\=\=/i
      page_end = /^\s*\<\/page\>\s*$/

      Dir.chdir(@download_dir)
      f = open('data.xml', 'r:utf-8')
      species_on = false
      get_page_info = false
      title = nil
      id = nil
      count = 0
      @data = []
      f.each do |l|
        if !get_page_info && l.match(page_start)
          get_page_info = true
        elsif get_page_info
          if title_match = l.match(title_re)
            title = title_match[1]
          elsif id_match = l.match(id_re)
            id = id_match[1]
            get_page_info = false
          end
        end
        if !species_on && title && !title.match(/Wikispecies/i) && (l.match(name_re) || l.match(classification_re))
          species_on = true
          @data << { scientificName: DwcaHunter::XML.unescape(title).to_json, taxonId: id }
          count += 1
          DwcaHunter::logger_write(self.object_id, "Extracted %s species data" % count) if count % BATCH_SIZE == 0
        end
        species_on = false if l.match(page_end)
      end
      DwcaHunter::logger_write(self.object_id, "Extracted total %s species data" % count)
      f.close
    end

    def generate_dwca
      DwcaHunter::logger_write(self.object_id, "Creating DarwinCore Archive file")
      gen = DarwinCore::Generator.new(File.join(@download_dir, "dwca.tar.gz"))
      core = [["http://rs.tdwg.org/dwc/terms/taxonID", "http://rs.tdwg.org/dwc/terms/scientificName"]]
      core += @data.map { |d| [d[:taxonId], d[:scientificName]] }
      eml = {
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
      gen.add_core(core, 'taxa.txt')
      gen.add_meta_xml
      gen.add_eml_xml(eml)
      gen.pack
      DwcaHunter::logger_write(self.object_id, "DarwinCore Archive file is created")
    end
  end
end

