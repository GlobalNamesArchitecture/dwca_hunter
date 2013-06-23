# encoding: utf-8
class DwcaHunter
  class ResourceArctos < DwcaHunter::Resource

    def initialize(opts = {})
      @title = 'Arctos'
      @url = 'http://arctos.database.museum/download/gncombined.zip'
      @UUID =  'eea8315d-a244-4625-859a-226675622312'
      @download_path = File.join(DEFAULT_TMP_DIR,
                                 'dwca_hunter',
                                 'arctos',
                                 'data.tar.gz')
      @synonyms = []
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
      generate_dwca
    end

    private

    def get_names
      Dir.chdir(@download_dir)
      Dir.entries(@download_dir).grep(/zip$/).each do |file|
        self.class.unzip(file) unless File.exists?(file.gsub(/zip$/,'csv'))
      end
      collect_names
      collect_synonyms
      collect_vernaculars
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

        puts "Processed %s vernaculars" % i if i % 10000 == 0
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
        taxon_id = row[fields[:taxon_name_id]]
        @synonyms << {
          taxon_id: row[fields[:related_taxon_name_id]],
          local_id: taxon_id,
          name_string: @names_index[taxon_id],
          #synonym_authority:      row[fields[:relation_authority]],
          taxonomic_status:       row[fields[:taxon_relationship]],
        }
        puts "Processed %s synonyms" % i if i % 10000 == 0
      end
    end

    def collect_names
      @names_index = {}
      file = open(File.join(@download_dir, 'taxonomy.csv'))
      fields = {}
      file.each_with_index do |row, i|
        if i == 0
          fields = get_fields(row)
          next
        end
        next unless  row[fields[:display_name]]
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
        code = row[fields[:nomenclatural_code]]

        @names << { taxon_id: taxon_id,
          local_id: taxon_id,
          name_string: name_string,
          kingdom: kingdom,
          phylum: phylum,
          klass: klass,
          order: order,
          family: family,
          genus: genus,
          code: code,
        }

        @names_index[taxon_id] = name_string
        puts "Processed %s names" % i if i % 10000 == 0
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
        'http://globalnames.org/terms/localID',
        'http://rs.tdwg.org/dwc/terms/scientificName',
        'http://rs.tdwg.org/dwc/terms/kingdom',
        'http://rs.tdwg.org/dwc/terms/phylum',
        'http://rs.tdwg.org/dwc/terms/class',
        'http://rs.tdwg.org/dwc/terms/order',
        'http://rs.tdwg.org/dwc/terms/family',
        'http://rs.tdwg.org/dwc/terms/genus',
        'http://rs.tdwg.org/dwc/terms/nomenclaturalCode',
        ]]
      @names.each do |n|
        @core << [n[:taxon_id], n[:taxon_id], n[:name_string],
          n[:kingdom], n[:phylum], n[:klass], n[:order], n[:family],
          n[:genus], n[:code]]
      end
      @extensions << {
        data: [[
          'http://rs.tdwg.org/dwc/terms/taxonID',
          'http://rs.tdwg.org/dwc/terms/vernacularName']],
        file_name: 'vernacular_names.txt',
        row_type: 'http://rs.gbif.org/terms/1.0/VernacularName' }

      @vernaculars.each do |v|
        @extensions[-1][:data] << [v[:taxon_id], v[:vernacular_name_string]]
      end

      @extensions << {
        data: [[
          'http://rs.tdwg.org/dwc/terms/taxonID',
          'http://globalnames.org/terms/localID',
          'http://rs.tdwg.org/dwc/terms/scientificName',
          'http://rs.tdwg.org/dwc/terms/taxonomicStatus',
          ]],
        file_name: 'synonyms.txt',
        }

      @synonyms.each do |s|
        @extensions[-1][:data] << [
          s[:taxon_id], s[:local_id],
          s[:name_string], s[:taxonomic_status]]
      end
      @eml = {
        id: @uuid,
        title: @title,
        authors: [
          {email: 'dustymc at gmail dot com'}
      ],
        metadata_providers: [
          { first_name: 'Dmitry',
            last_name: 'Mozzherin',
            email: 'dmozzherin@gmail.com' }
      ],
        abstract: 'Arctos is an ongoing effort to integrate access to specimen data, collection-management tools, and external resources on the internet.',
        url: @url
      }
      super
    end
  end
end

