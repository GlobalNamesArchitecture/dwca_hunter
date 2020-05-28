# encoding: utf-8
module DwcaHunter
  class ResourceMCZ < DwcaHunter::Resource

    def initialize(opts = {})
      @command = 'mcz'
      @title = 'MCZbase'
      @url = 'https://uofi.box.com/shared/static/x1dp86l48hyjkwfl106ejj25ormkzwip.gz'
      @UUID =  'c79d055b-211b-40de-8e27-618011656265'
      @download_path = File.join(Dir.tmpdir,
                                 'dwca_hunter',
                                 'mcz',
                                 'data.tar.gz')
      @synonyms = []
      @names = []
      @vernaculars = []
      @extensions = []
      @synonyms_hash = {}
      @vernaculars_hash = {}
      super(opts)
    end

    def download
      puts "Downloading cached verion of the file. Ask MCZ for update."
        `curl -s -L #{@url} -o #{@download_path}`
    end

    def unpack
      unpack_tar
    end

    def make_dwca
      DwcaHunter::logger_write(self.object_id, 'Extracting data')
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
      file = CSV.open(File.join(@download_dir, 'taxonomy_export_2020May26.csv'),
       headers: true)
      file.each_with_index do |row, i|
        canonical = row['SCIENTIFIC_NAME']
        authors = row['AUTHOR_TEXT']
        kingdom = row['KINGDOM']
        phylum = row['PHYLUM']
        klass = row['PHYLCLASS']
        order = row['PHYLORDER']
        family = row['FAMILY']
        genus = row['GENUS']
        code = row['NOMENCLATURAL_CODE']

        taxon_id = "gn_#{i+1}"
        name_string = "#{canonical} #{authors}".strip
        @names << { taxon_id: taxon_id,
          name_string: name_string,
          kingdom: kingdom,
          phylum: phylum,
          klass: klass,
          order: order,
          family: family,
          genus: genus,
          code: code,
        }
        puts "Processed %s names" % i if i % 10000 == 0
      end
    end

    def generate_dwca
      DwcaHunter::logger_write(self.object_id,
                               'Creating DarwinCore Archive file')
      @core = [['http://rs.tdwg.org/dwc/terms/taxonID',
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
        @core << [n[:taxon_id], n[:name_string],
          n[:kingdom], n[:phylum], n[:klass], n[:order], n[:family],
          n[:genus], n[:code]]
      end

      @eml = {
        id: @uuid,
        title: @title,
        authors: [
          { first_name: 'MCZ',
            last_name: 'Harvard University',
          },
        ],
        metadata_providers: [
          { first_name: 'Paul',
            last_name: 'Morris',
          }
      ],

        abstract: 'The Museum of Comparative Zoology was founded in 1859 on ' \
        'the concept that collections are an integral and fundamental ' \
        'component of zoological research and teaching. This more than ' \
        '150-year-old commitment remains a strong and proud tradition for ' \
        'the MCZ. The present-day MCZ contains over 21-million specimens in ' \
        'ten research collections which comprise one of the world\'s richest ' \
        'and most varied resources for studying the diversity of life. The ' \
        'museum serves as the primary repository for zoological specimens ' \
        'collected by past and present Harvard faculty-curators, staff and ' \
        'associates conducting research around the world. As a premier ' \
        'university museum and research institution, the specimens and ' \
        'their related data are available to researchers of the scientific ' \
        'and museum community. doi:10.5281/zenodo.891420',
        url: @url
      }
      super
    end
  end
end
