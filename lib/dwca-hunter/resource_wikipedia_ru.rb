# encoding: utf-8
class DwcaHunter
  class ResourceWikipediaRu < DwcaHunter::Resource
    def initialize(opts = {})
      @url = "http://dumps.wikimedia.org/ruwiki/latest/ruwiki-latest-pages-articles.xml.bz2"
      @url = opts[:url] if opts[:url]
      @uuid = "32bca176-24e2-4582-9f77-3101b017b9dd"
      @download_path = File.join(DEFAULT_TMP_DIR, "dwca_hunter", "wikipedia_ru", "data.xml.bz2")
      super(opts)
    end

    def unpack
      unpack_bz2
    end

    def collect_data
      enrich_data
    end

  private

    def enrich_data
      DwcaHunter::logger_write(self.object_id, "Extracting data from xml file...")
      page_start = /^\s*\<page\>\s*$/
      title_re = /\<title\>(.*)\<\/title\>/
      id_re = /^\s*\<id\>(.*)\<\/id\>\s*$/
      en_taxon = /\{\{taxobox\s/i
      ru_taxon = /\{\{таксон\s/i
      taxon_end = /^\|?\s*\}\}/
      separator = "_|_SEPARATOR_|_\n"
      page_end = /^\s*\<\/page\>\s*$/

      Dir.chdir(@download_dir)
      f = open('data.xml', 'r:utf-8')
      res = open('enriched_data.txt', 'w:utf-8')
      species_on = false
      get_page_info = false
      title = nil
      id = nil
      count = 0
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
        if !species_on && (l.match(en_taxon) || l.match(ru_taxon))
          species_on = true
          res.write(separator)
          res.write("title:" + title + "\n")
          res.write("id:" + id + "\n")
          count += 1
          DwcaHunter::logger_write(self.object_id, "Extracted %s species data" % count) if count % 100 == 0
          res.write(l)
        elsif species_on
          res.write(l)
        end
        species_on = false if (l.match(taxon_end) || l.match(page_end))
      end
      DwcaHunter::logger_write(self.object_id, "Extracted total %s species data" % count)
      f.close
      res.close
    end
  end
end
