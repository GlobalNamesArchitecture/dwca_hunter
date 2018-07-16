# frozen_string_literal: true

class DwcaHunter
  # Harvesting resource for Open Tree of Life
  class ResourceOpenTree < DwcaHunter::Resource
    def initialize(opts = {})
      @title = "Open Tree of Life Reference Taxonomy"
      @uuid = "e10865e2-cdd9-4f97-912f-08f3d5ef49f7"
      @data = []
      @extensions = []
      @count = 1
      @clades = {}
      @core = [["http://rs.tdwg.org/dwc/terms/taxonId",
                "http://globalnames.org/terms/localID",
                "http://purl.org/dc/terms/scientificName",
                "http://purl.org/dc/terms/parentNameUsageId",
                "http://purl.org/dc/terms/taxonRank",
                "http://globalnames.org/ottCrossMaps",
                "http://globalnames.org/ottNotes"]]
      @eml = {
        id: @uuid,
        title: @title,
        authors: [{ url: "https://tree.opentreeoflife.org" }],
        abstract: "Open Tree of Life aims to construct a comprehensive, " \
                  "dynamic and digitally-available tree of life by " \
                  "synthesizing published phylogenetic trees along with" \
                  "taxonomic data. The project is a collaborative effort" \
                  "between 11 PIs across 10 institutions.",
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
            email: "dmozzherin@gmail.com" }
        ],
        url: @url
      }
      @url = "http://opendata.globalnames.org/id-crossmap/ott3.0.tgz"
      @download_path = File.join(DEFAULT_TMP_DIR, "dwca_hunter",
                                 "opentree", "data.tar.gz")
      super
    end

    def unpack
      unpack_tar if @needs_unpack
    end

    def make_dwca
      DwcaHunter.logger_write(object_id, "Extracting data")
      collect_data
      generate_dwca
    end

    def download
      return unless @needs_download
      DwcaHunter.logger_write(object_id, "Downloading file -- "\
                               "it will take some time...")
      dlr = DwcaHunter::Downloader.new(url, @download_path)
      dlr.download
    end

    private

    def collect_data
      set_vars
      classification
    end

    def set_vars
      @taxonomy = File.join(@download_dir, "ott", "taxonomy.tsv")
      @synonyms = File.join(@download_dir, "ott", "synonyms.tsv")
    end

    def classification
      @classification = []
      @names = {}
      DwcaHunter.logger_write(object_id, "Building classification")
      open(@taxonomy).each_with_index do |line, i|
        if ((i + 1) % BATCH_SIZE).zero?
          DwcaHunter.logger_write(object_id,
                                  "Traversed #{i + 1} taxonomy lines")
        end
        @classification << line.split("|").map(&:strip)
      end
    end

    def generate_dwca
      DwcaHunter.logger_write(object_id, "Creating DarwinCore Archive file")
      DwcaHunter.logger_write(object_id, "Assembling Core Data")
      generate_core
      generate_synonyms
      super
    end

    def generate_core
      @classification.each_with_index do |d|
        if (count % BATCH_SIZE).zero?
          DwcaHunter.logger_write(object_id, "Traversing #{count} core " \
                                  "data record")
        end
        @core << [d[0], d[0], d[2], d[1], d[3], d[4], d[5]]
      end
    end

    def synonyms
      []
    end

    def generate_synonyms
      @extensions <<
        { data: [["http://rs.tdwg.org/dwc/terms/taxonId",
                  "http://rs.tdwg.org/dwc/terms/scientificName",
                  "http://rs.tdwg.org/dwc/terms/taxonomicStatus"]],
          file_name: "synonyms.txt" }

      synonyms.each do |synonym|
        @extensions.first[:data] << [d[:id], synonym[:scientificName],
                                     synonym[:taxonomicStatus]]
      end
    end
  end
end
