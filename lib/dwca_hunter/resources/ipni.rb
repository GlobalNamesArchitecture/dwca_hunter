require "xz"

module DwcaHunter
  # Resource for FishBase
  class ResourceIPNI < DwcaHunter::Resource
    attr_reader :title, :abbr
    def initialize(opts = {}) #download: false, unpack: false})
      @command = "ipni"
      @title = "The International Plant Names Index"
      @abbr = "IPNI"
      @url = "https://uofi.box.com/shared/static/s0x4xjonxt54pi89n543gdmttrdqd6iv.xz"
      @uuid = "6b3905ce-5025-49f3-9697-ddd5bdfb4ff0"
      @download_path = File.join(Dir.tmpdir, "dwca_hunter", "ipni",
                                 "ipni.csv.xz")
      @extensions = []
      super
    end

    def unpack
      puts "Unpacking #{@download_path}"
      XZ.decompress_file(@download_path, @download_path[0...-3] )
    end

    def download
      puts "Download by hand from"
      puts "https://storage.cloud.google.com/ipni-data/ipniWebName.csv.xz"
      puts "and copy to given url"
        `curl -s -L #{@url} -o #{@download_path}`
    end

    def make_dwca
      organize_data
      generate_dwca
    end

    private

    def organize_data
      DwcaHunter::logger_write(self.object_id,
                               "Organizing data")
      # snp = ScientificNameParser.new
      @data = CSV.open(@download_path[0...-3],
         col_sep: "|", quote_char: "щ", headers: true)
        .each_with_object([]) do |row, data|
        name = row['taxon_scientific_name_s_lower'].strip
        au = row['authors_t'].to_s.strip
        name = "#{name} #{au}" if au != ''
        id = row["id"].split(":")[-1]
        data << { taxon_id: id,
                  local_id: id,
                  family: row["family_s_lower"],
                  genus: row["genus_s_lower"],
                  scientific_name: name,
                  rank: row["rank_s_alphanum"]
                }

      end
    end

    def generate_dwca
      DwcaHunter::logger_write(self.object_id,
                               'Creating DarwinCore Archive file')
      core_init
      eml_init
      DwcaHunter::logger_write(self.object_id, 'Assembling Core Data')
      count = 0
      @data.each do |d|
        count += 1
        if count % 10000 == 0
          DwcaHunter::logger_write(self.object_id, "Core row #{count}")
        end
        @core << [d[:taxon_id], d[:local_id],
                  d[:scientific_name], d[:rank],
                  d[:family], d[:genus]]
      end
      super
    end

    def eml_init
      @eml = {
        id: @uuid,
        title: @title,
        authors: [],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
          }
      ],
        abstract: "The International Plant Names Index (IPNI) is a database " \
                  "of the names and associated basic bibliographical " \
                  "details of seed plants, ferns and lycophytes. Its goal " \
                  "is to eliminate the need for repeated reference to " \
                  "primary sources for basic bibliographic information " \
                  "about plant names. The data are freely available and are " \
                  "gradually being standardized and checked. IPNI will be a " \
                  "dynamic resource, depending on direct contributions by " \
                  "all members of the botanical community.",
        url: "http://www.ipni.org"
      }
    end

    def core_init
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
                "http://globalnames.org/terms/localID",
                "http://rs.tdwg.org/dwc/terms/scientificName",
                "http://rs.tdwg.org/dwc/terms/taxonRank",
                "http://rs.tdwg.org/dwc/terms/family",
                "http://rs.tdwg.org/dwc/terms/genus"]]
    end
  end
end
