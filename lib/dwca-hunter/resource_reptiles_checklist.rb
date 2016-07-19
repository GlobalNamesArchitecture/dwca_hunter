# encoding: utf-8
require 'biodiversity'
require 'csv'

class DwcaHunter
  class ResourceReptilesChecklist < DwcaHunter::Resource
    def initialize(opts = {})
      @title = "The Reptile Database"
      @uuid = "c24e0905-4980-4e1d-aff2-ee0ef54ea1f8"
      @data = []
      @extensions = []
      @download_path = File.join(DEFAULT_TMP_DIR, 'dwca_hunter',
                                 'reptilesdb', 'fake.tar.gz')
      super
    end

    def needs_unpack?
      false
    end

    def download
    end

    def make_dwca
      organize_data
      generate_dwca
    end

    private
    def organize_data
      DwcaHunter::logger_write(self.object_id,
                               "Organizing data")
      path = File.join(__dir__, "..",
                       "..", "files", "reptile_checklist_2014_12.csv")
      snp = ScientificNameParser.new
      @data = CSV.open(path).each_with_object([]) do |row, data|
        res = {}
        name = row[0..1].join(" ")
        res[:species] = snp.parse(name)[:scientificName][:normalized]
        res[:subspecies] = []
        if row[2]
          row[2].split("\n").each do |ssp|
            res[:subspecies] << snp.parse(ssp)[:scientificName][:normalized]
          end
        end
        res[:vernaculars] = []
        if row[3]
          row[3].split("\n").each do |v|
            lang = "en"
            v.gsub!(/^E: /, '')
            v.gsub!(/^G: /) do |m|
              lang = "de" if m
              ""
            end
            v.split(",").each do |name|
              res[:vernaculars] << { name: name.strip, lang: lang }
            end
          end
        end
        if row[4]
          res[:family] = row[4].match(/^[A-Za-z]+/)[0]
        end
        data << res
      end
    end

    def generate_dwca
      DwcaHunter::logger_write(self.object_id,
                               "Creating DarwinCore Archive file")
      @core = [['http://rs.tdwg.org/dwc/terms/taxonID',
                'http://rs.tdwg.org/dwc/terms/parentNameUsageID',
                'http://rs.tdwg.org/dwc/terms/scientificName',
                'http://rs.tdwg.org/dwc/terms/taxonRank']]
      @extensions << { data: [['http://rs.tdwg.org/dwc/terms/taxonID',
                               'http://rs.tdwg.org/dwc/terms/vernacularName',
                               'http://purl.org/dc/terms/language']],
                               file_name: 'vernacular_names.txt',
                               row_type: 'http://rs.gbif.org/terms/1.0/VernacularName'
      }
      families = {}
      count = 1
      class_id = count
      @core << [count, nil, "Reptilia", "class"]
      @data.each_with_index do |record|
        count += 1
        family_id = families[record[:family]]
        unless family_id
          count += 1
          family_id = count
          families[record[:family]] = family_id
          @core << [family_id, class_id, record[:family], "family"]
        end
        count += 1
        species_id = count
        @core << [species_id, family_id, record[:species], "species"]
        record[:vernaculars].each do |v|
          @extensions[0][:data] << [species_id, v[:name], v[:lang]]
        end
        record[:subspecies].each do |ssp|
          count += 1
          row = [count, species_id, ssp, "subspecies"]
          @core << row
        end
      end
      @eml = {
        id: @uuid,
        title: @title,
        authors: [
          {
            first_name: "Peter",
            last_name: "Uetz",
            email: "info@reptile-database_org"
          },
          {
            first_name: "Jiri",
            last_name: "Hosek",
            email: "jiri.hosek@reptarium.cz"
          }
        ],
        metadata_providers: [
          { first_name: 'Dmitry',
            last_name: 'Mozzherin',
            email: 'dmozzherin@gmail.com' }
        ],
        abstract: "This database provides a catalogue of all living reptile "\
        "species and their classification. The database covers "\
        "all living snakes, lizards, turtles, amphisbaenians, "\
        "tuataras, and crocodiles. Currently there are about "\
        "9,500 species including another 2,800 subspecies "\
        "(statistics). The database focuses on taxonomic data, "\
        "i.e. names and synonyms, distribution and type data "\
        "and literature references.",
        url: "http://www.reptile-database.org"
      }
      super
    end
  end
end
