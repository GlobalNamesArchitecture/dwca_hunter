# encoding: utf-8

module DwcaHunter
  class ResourceFreebase < DwcaHunter::Resource
    def initialize(opts = {})
      @command = "freebase"
      @title = 'Freebase'
      @uuid = 'bacd21f0-44e0-43e2-914c-70929916f257'
      @download_path = File.join(Dir.tmpdir,
                                 'dwca_hunter',
                                 'freebase',
                                 'data.json')
      @data = []
      @all_taxa = {}
      @cleaned_taxa = {}
      @extensions = []
      super
    end

    def needs_unpack?
      false
    end

    def make_dwca
      organize_data
      generate_dwca
    end

    def download
      DwcaHunter::logger_write(self.object_id,
                               'Querying freebase for species information...')
      q = {
        query: [{
          type: '/biology/organism_classification',
          id: nil,
          guid: nil,
          name: nil,
          scientific_name: nil,
          synonym_scientific_name: [],
          higher_classification: {
            id: nil,
            guid: nil,
            scientific_name: nil,
            optional: true,
          },
        }],
        cursor: true,
      }

      run_query(q)

      data = JSON.pretty_generate @data
      f = open(@download_path, 'w:utf-8')
      f.write(data)
      f.close
    end

    private

    def run_query(q)
      count = 0
      requests_num = 0
      while true
        freebase_url = "http://api.freebase.com/api/service/mqlread?query=%s" %
          URI.encode(q.to_json)
        res = JSON.load RestClient.get(freebase_url)
        requests_num += 1
        break if res['result'] == nil || res['result'].empty?
        if requests_num % 10 == 0
          DwcaHunter::logger_write(self.object_id,
                                   "Received %s names" % count)
        end
        count += res['result'].size
        res['result'].each { |d| @data << d }
        q[:cursor] = res['cursor']
      end
    end

    def organize_data
      @data = JSON.load(open(@download_path, 'r:utf-8').read)
      @data.each do |d|
        scientific_name = d['scientific_name'].to_s
        id = d["id"]
        parent_id = d['higher_classification'] ?
                    d['higher_classification']["id"] :
                    nil
        synonyms = d['synonym_scientific_name']
        @all_taxa[id] = { id: id,
                          parent_id: parent_id,
                          scientific_name: scientific_name,
                          synonyms: synonyms }
      end

      @all_taxa.each do |k, v|
        next unless v[:scientific_name] && v[:scientific_name].strip != ""
        parent_id = v[:parent_id]
        until (@all_taxa[parent_id] &&
                @all_taxa[parent_id][:scientific_name]) || parent_id.nil?
          puts "did not find parent %s" % parent_id
          parent_id = @all_taxa[parent_id]
        end
        parent_id = nil if v[:id] == parent_id
        v[:parent_id] = parent_id
        @cleaned_taxa[k] = v
      end

    end

    def generate_dwca
      DwcaHunter::logger_write(self.object_id,
                               'Creating DarwinCore Archive file')
      @core = [['http://rs.tdwg.org/dwc/terms/taxonID',
                'http://rs.tdwg.org/dwc/terms/scientificName',
                'http://rs.tdwg.org/dwc/terms/parentNameUsageID']]

      @extensions << { data: [[
        'http://rs.tdwg.org/dwc/terms/TaxonID',
        'http://rs.tdwg.org/dwc/terms/scientificName',
      ]], file_name: 'synonyms.txt' }
      DwcaHunter::logger_write(self.object_id,
                    'Creating synonyms extension for DarwinCore Archive file')
      count = 0
      @cleaned_taxa.each do |key, taxon|
        count += 1
        @core << [taxon[:id], taxon[:scientific_name], taxon[:parent_id]]
        if count % BATCH_SIZE == 0
          DwcaHunter::logger_write(self.object_id,
                                 "Traversing %s extension data record" % count)
        end
        taxon[:synonyms].each do |name|
          @extensions[-1][:data] << [taxon[:id], name]
        end
      end
      @eml = {
        id: @uuid,
        title: @title,
        license: 'http://creativecommons.org/licenses/by-sa/3.0/',
        authors: [
          { url: 'http://www.freebase.com/home' }],
        abstract: 'An entity graph of people, places and things, ' +
                  'built by a community that loves open data.',
        metadata_providers: [
          { first_name: 'Dmitry',
            last_name: 'Mozzherin',
            email: 'dmozzherin@mbl.edu' }],
        url: 'http://www.freebase.com/home'
      }
      super
    end

  end
end
