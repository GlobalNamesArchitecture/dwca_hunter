# frozen_string_literal: true

module DwcaHunter
  class ResourceIOCWorldBird < DwcaHunter::Resource
    def initialize(opts = {})
      @command = 'ioc-world-bird'
      @title = 'IOC World Bird List'
      @url = 'https://uofi.box.com/shared/static/znsd734a78saq87hes979p5uspgkzy93.csv'
      @UUID = '6421ffec-38e3-40fb-a6d9-af27238a47a1'
      @download_path = File.join(Dir.tmpdir,
                                 'dwca_hunter',
                                 'ioc-bird',
                                 'data.csv')
      @synonyms = []
      @names = []
      @vernaculars = []
      @extensions = []
      @synonyms_hash = {}
      @vernaculars_hash = {}
      super(opts)
    end

    def download
      puts 'Downloading cached and converted to csv version.'
      puts 'CHECK FOR NEW VERSION at'
      puts 'https://www.worldbirdnames.org/ioc-lists/master-list-2/'
      puts 'Use libreoffice to convert to csv.'
      `curl -s -L #{@url} -o #{@download_path}`
    end

    def unpack; end

    def make_dwca
      DwcaHunter.logger_write(object_id, 'Extracting data')
      get_names
      generate_dwca
    end

    private

    def get_names
      Dir.chdir(@download_dir)
      collect_names
    end

    def collect_names
      @names_index = {}
      file = CSV.open(File.join(@download_dir, 'data.csv'),
                      headers: true)
      order = ''
      family = ''
      genus = ''
      species = ''
      count = 0
      file.each do |row|
        order1 = row['Order']
        order = order1.capitalize if order1.to_s != ''

        family1 = row['Family (Scientific)']
        family = family1.capitalize if family1.to_s != ''

        genus1 = row['Genus']
        genus = genus1.capitalize if genus1.to_s != ''

        species1 = row['Species (Scientific)']
        species = species1 if species1.to_s != ''

        subspecies = row['Subspecies']
        next if species.to_s == ''

        count += 1
        taxon_id = "gn_#{count}"
        name = {
          taxon_id: taxon_id,
          kingdom: 'Animalia',
          phylum: 'Chordata',
          klass: 'Aves',
          order: order,
          family: family,
          genus: genus,
          code: 'ICZN'
        }
        if subspecies.to_s == ''
          auth = row['Authority'].to_s
          auth = DwcaHunter.normalize_authors(auth) if auth != ''
          name[:name_string] = clean(
            "#{genus} #{species} #{auth}"
            .strip
          )
          @names << name
          vernacular = row['Species (English)']
          if vernacular.to_s != ''
            vernaclar = { taxon_id: taxon_id, vern: vernacular, lang: 'en' }
            @vernaculars << vernaclar
          end
          species = ''
        else
          name[:name_string] = clean(
            "#{genus} #{species} #{subspecies} #{row['Authority']}"
            .strip
          )
          @names << name
          species = ''
          subspecies = ''
        end
      end
    end

    def clean(n)
      n = n.gsub(/†/, '')
      n.gsub(/\s+/, ' ')
    end

    def generate_dwca
      DwcaHunter.logger_write(object_id,
                              'Creating DarwinCore Archive file')
      @core = [['http://rs.tdwg.org/dwc/terms/taxonID',
                'http://rs.tdwg.org/dwc/terms/scientificName',
                'http://rs.tdwg.org/dwc/terms/kingdom',
                'http://rs.tdwg.org/dwc/terms/phylum',
                'http://rs.tdwg.org/dwc/terms/class',
                'http://rs.tdwg.org/dwc/terms/order',
                'http://rs.tdwg.org/dwc/terms/family',
                'http://rs.tdwg.org/dwc/terms/genus',
                'http://rs.tdwg.org/dwc/terms/nomenclaturalCode']]
      @names.each do |n|
        @core << [n[:taxon_id], n[:name_string],
                  n[:kingdom], n[:phylum], n[:klass], n[:order], n[:family],
                  n[:genus], n[:code]]
      end
      @extensions << {
        data: [[
          'http://rs.tdwg.org/dwc/terms/taxonID',
          'http://rs.tdwg.org/dwc/terms/vernacularName',
          'http://purl.org/dc/terms/language'
        ]],
        file_name: 'vernacular_names.txt',
        row_type: 'http://rs.gbif.org/terms/1.0/VernacularName'
      }

      @vernaculars.each do |v|
        @extensions[-1][:data] << [v[:taxon_id], v[:vern], v[:lang]]
      end

      @eml = {
        id: @uuid,
        title: @title,
        authors: [
          { first_name: 'Per',
            last_name: 'Alstrom' },
          { first_name: 'Mike',
            last_name: 'Blair' },
          { first_name: 'Rauri',
            last_name: 'Bowie' },
          { first_name: 'Nigel',
            last_name: 'Redman' },
          { first_name: 'Jon',
            last_name: 'Fjeldsa' },
          { first_name: 'Phil',
            last_name: 'Gregory' },
          { first_name: 'Leo',
            last_name: 'Joseph' },
          { first_name: 'Peter',
            last_name: 'Kovalik' },
          { first_name: 'Adolfo',
            last_name: 'Navarro-Siguenza' },
          { first_name: 'David',
            last_name: 'Parkin' },
          { first_name: 'Alan',
            last_name: 'Peterson' },
          { first_name: 'Douglas',
            last_name: 'Pratt' },
          { first_name: 'Pam',
            last_name: 'Rasmussen' },
          { first_name: 'Frank',
            last_name: 'Rheindt' },
          { first_name: 'Robert',
            last_name: 'Ridgely' },
          { first_name: 'Peter',
            last_name: 'Ryan' },
          { first_name: 'George',
            last_name: 'Sangster' },
          { first_name: 'Dick',
            last_name: 'Schodde' },
          { first_name: 'Minturn',
            last_name: 'Wright' }
        ],
        metadata_providers: [
          { first_name: 'Dmitry',
            last_name: 'Mozzherin',
            email: 'dmozzherin@gmail.com' }
        ],
        abstract: 'The IOC World Bird List is an open access resource of ' \
                  'the international community of ornithologists.',
        url: 'https://www.worldbirdnames.org'
      }
      super
    end
  end
end
