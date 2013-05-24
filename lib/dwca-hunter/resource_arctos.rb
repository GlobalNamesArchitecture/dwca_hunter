# encoding: utf-8
class DwcaHunter
  class ResourceArctos < DwcaHunter::Resource

    def initialize(opts = {})
      @title = 'GNUB'
      @url = 'http://arctos.database.museum/download/gncombined.zip'
      @UUID =  'eea8315d-a244-4625-859a-226675622312'
      @download_path = File.join(DEFAULT_TMP_DIR, 
                                 'dwca_hunter', 
                                 'arctos', 
                                 'data.tar.gz')
      @synonyms = {}
      @names = []
      @vernaculars = []
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
      # generate_dwca
    end

    private

    def get_names
      Dir.chdir(@download_dir)
      sleep 1 until Dir.entries(".").grep(/zip$/).size == 3
      Dir.entries(@download_dir).grep(/zip$/).each do |file|
        self.class.unzip(file) unless File.exists?(file.gsub!(/zip$/,'csv'))
      end
      collect_names 
      collect_vernaculars
      require 'ruby-debug'; debugger
      puts ''
    end

    def collect_vernaculars
      file = open(File.join(@download_dir, 'common_name.csv'))
      fields = {}
      file.each_with_index do |row, i|

        if i == 0
          fields = get_fields(row) 
          next
        end
        
        row = split_row(row)

        taxon_id = row[fields[:taxon_name_id]]
        vernacular_name_string = row[fields[:common_name]]

        @vernaculars << {
          taxon_id: taxon_id,
          vernacular_name_string: vernacular_name_string
        }
      end
    end

    def collect_synonyms
      file = open(File.join(@download_dir, 'taxon_relations.csv'))
      fields = {}
      file.each_with_index do |row, i|
        if i == 0
          fields = get_fields(row) 
          next
        end

        row = split_row(row)
        taxon_id = row[fields[:related_taxon_name_id]]
        unless @synonyms[taxon_id]
          @synonyms[taxon_id] = {
            accepted_name_usage_id: row[fields[:taxon_name_id]],
            synonym_authority:      row[fields[:relation_authority]],
            taxonomic_status:       row[fields[:taxon_relationship]],
          }
        else
          puts "Double synonym: %s" % taxon_id
        end
      end
    end

    def collect_names
      collect_synonyms
      file = open(File.join(@download_dir, 'taxonomy.csv'))
      fields = {}
      file.each_with_index do |row, i|
        if i == 0
          fields = get_fields(row) 
          next
        end

        row = split_row(row)
        taxon_id = row[fields[:taxon_name_id]]
        name_string = row[fields[:display_name]].gsub(/<\/?i>/,'')
        kingdom = row[fields[:kingdom]]
        phylum = row[fields[:phylum]]
        klass = row[fields[:phylclass]]
        subclass = row[fields[:subclass]]
        order = row[fields[:phylorder]]
        suborder = row[fields[:suborder]]
        superfamily = row[fields[:superfamily]]
        family = row[fields[:family]]
        subfamily = row[fields[:subfamily]]
        tribe = row[fields[:tribe]]
        genus = row[fields[:genus]]
        subgenus = row[fields[:subgenus]] 
        species = row[fields[:species]]
        subspecies = row[fields[:subspecies]]
        accepted_name_usage_id = ''
        taxonomic_status = ''

        if @synonyms[taxon_id]
          accepted_name_usage_id = @synonyms[taxon_id][:accepted_name_usage_id]
          taxonomic_status = @synonyms[taxon_id][:taxonomic_status]
        end

        @names << { taxon_id: taxon_id,
          name_string: name_string,
          kingdom: kingdom,
          phylum: phylum,
          klass: klass,
          subclass: subclass,
          order: order,
          suborder: suborder,
          superfamily: superfamily,
          family: family,
          subfamily: subfamily,
          tribe: tribe,
          genus: genus,
          subgenus: subgenus,
          species: species,
          subspecies: subspecies,
          accepted_name_usage_id: accepted_name_usage_id,
          taxonomic_status: taxonomic_status,
        }

        break if i > 1000
      end
    end

    def split_row(row)
      row = row.strip.gsub(/^"/, '').gsub(/"$/, '')
      row.split('","')
    end

    def get_fields(row)
      row = row.split(",")
      encoding_options = {
        :invalid           => :replace,
        :undef             => :replace,
        :replace           => '',      
        :universal_newline => true    
      }
      num_ary = (0...row.size).to_a 
      row = row.map do |f| 
        f = f.strip.downcase
        f = f.encode ::Encoding.find('ASCII'), encoding_options
        f.to_sym
      end
      Hash[row.zip(num_ary)]
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

