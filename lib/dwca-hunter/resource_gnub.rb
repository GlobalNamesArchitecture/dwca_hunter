# encoding: utf-8
class DwcaHunter
  class ResourceGNUB < DwcaHunter::Resource
    def initialize(opts = {})
      @title = 'GNUB'
      @url = 'http://gnub.org/datadump/gni_export.zip'
      @UUID =  'd34ed224-78e7-485d-a478-adc2558a0f68'
      @download_path = File.join(DEFAULT_TMP_DIR, 
                                 'dwca_hunter', 
                                 'gnub', 
                                 'data.tar.gz')
      @ranks = {} 
      @kingdoms = {}
      @authors = {}
      @vernaculars = {}
      @synonyms = {}
      @synonym_of = {}
      @names = []
      @extensions = []
      super(opts)
      @gnub_dir = File.join(@download_dir, 'gnub')
    end

    def unpack
      unpack_zip
    end
    
    def make_dwca
      DwcaHunter::logger_write(self.object_id, 'Extracting data')
      get_names
      generate_dwca
    end

    private

    def get_names
      codes = get_codes
      file = Dir.entries(@download_dir).grep(/txt$/).first
      open(File.join(@download_dir, file)).each_with_index do |line, i|
        next if i == 0 || (data = line.strip) == '' 
        data = data.split("\t")
        protolog = data[0].downcase
        protolog_path = data[1].downcase
        name_string = data[2]
        rank = data[3]
        code = codes[data[4].to_i]
        taxon_id = UUID.create_v5(name_string + 
                                  protolog_path + 
                                  rank, GNA_NAMESPACE)
        @names << { taxon_id: taxon_id,
                    name_string: name_string,
                    protolog: protolog,
                    protolog_path: protolog_path,
                    code: code,
                    rank: rank }
      end
    end

    def get_codes
      codes_url = 'http://resolver.globalnames.org/nomenclatural_codes.json'
      codes = RestClient.get(codes_url)
      codes = JSON.parse(codes, symbolize_names: true)
      codes.inject({}) do |res, c|
        res[c[:id]] = c[:code]
        res
      end
    end

    def generate_dwca
      DwcaHunter::logger_write(self.object_id, 
                               'Creating DarwinCore Archive file')
      @core = [['http://rs.tdwg.org/dwc/terms/taxonID',
                'http://rs.tdwg.org/dwc/terms/originalNameUsageID',
                'http://globalnames.org/terms/originalNameUsageIDPath',
                'http://rs.tdwg.org/dwc/terms/scientificName',
                'http://rs.tdwg.org/dwc/terms/nomenclaturalCode',
                'http://rs.tdwg.org/dwc/terms/taxonRank']]
      @names.each do |n|
        @core << [n[:taxon_id], n[:protolog], n[:name_string], 
                  n[:protolog_path], n[:code], n[:rank]]
      end
      @eml = {
          id: @uuid,
          title: @title,
          authors: [
            {email: 'deepreef@bishopmuseum.org'}
          ],
          metadata_providers: [
            { first_name: 'Dmitry',
              last_name: 'Mozzherin',
              email: 'dmozzherin@gmail.com' }
            ],
          abstract: 'Global Names Usage Bank',
          url: 'http://www.zoobank.org'
      }
      super
    end
  end
end

