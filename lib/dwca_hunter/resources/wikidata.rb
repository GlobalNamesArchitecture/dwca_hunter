# frozen_string_literal: true

module DwcaHunter
  class ResourceWikidata < DwcaHunter::Resource
    def initialize(opts = {download: false, unpack: false})
      @command = "wikidata"
      @title = "Wikidata"
      @url = "https://uofi.box.com/shared/static/imd7i6asfo0277b9gj8bwnqlbe3d6tv3.gz"
      @UUID = "f972c3e7-9da8-48d1-aa00-5c6c56c24614"
      @download_path = File.join(Dir.tmpdir,
                                 "dwca_hunter",
                                 "wikidata",
                                 "data.tar.gz")
      @synonyms = []
      @names = []
      @vernaculars = []
      @extensions = []
      @synonyms_hash = {}
      @vernaculars_hash = {}
      super(opts)
    end

    def download
      puts "Downloading Wikidata file."
      # -L allows redirections
      `curl -L -s #{@url} -o #{@download_path}`
    end

    def unpack
      unpack_tar
    end

    def make_dwca
      DwcaHunter.logger_write(object_id, "Extracting data")
      get_genera
      get_species
      generate_dwca
    end

    private

    def get_genera
      Dir.chdir(@download_dir)
      collect_genera
    end

    def get_species
      Dir.chdir(@download_dir)
      collect_names
    end

    def get_authors(s)
      return if s.strip.size == 0
      res = []
      s = s.gsub(/'([\}:,])/, '"\1')
      s = s.gsub(/([:,]\s+|\{)'/, '\1"')
      jsn = JSON.parse(s)
      jsn.each do |k, v|
        res << v
      end
      res.join(", ")
    end

    def get_year(s)
      return "" if s.nil?
    if s[0,4].to_i > 1500
    return s[0,4]
    end
      return ""
    end

    def collect_genera
      puts "Processing genera"
      file = CSV.open(File.join(@download_dir, "genus_groups.tsv"),
                      headers: true, col_sep: "\t")

      file.each_with_index do |row, i|

        next if row["id"].empty?

        genus = row["scientific_name"]
        rank = row["rank"]
        taxon_id = row["id"]
        authors = get_authors(row["authors"])
        year = get_year(row["published_in_year"])
        if authors.size > 0 && year.size == 4
          authors += ", " + year
        end
        unless authors.size.zero?
          genus += " " + authors
      end
    
        res = { taxon_id: taxon_id,
                name_string: genus,
                rank: rank
        }
        @names << res
        puts "Processed #{i} names" if (i % 100_000).zero?
      end
    end


    def collect_names
      puts "Processing species"
      file = CSV.open(File.join(@download_dir, "species_groups.tsv"),
                      headers: true, col_sep: "\t")

      file.each_with_index do |row, i|

        next if row["id"].empty?

        name = row["scientific_name"]
        rank = row["rank"]
        taxon_id = row["id"]
    
        res = { taxon_id: taxon_id,
                name_string: name,
                rank: rank
        }
        @names << res
        puts "Processed #{i} names" if (i % 100_000).zero?
      end
    end

    def update_vernacular(taxon_id, canonical)
      return unless @vernaculars_hash.key?(canonical)

      @vernaculars_hash[canonical].each do |vern|
        @vernaculars << { taxon_id: taxon_id, vern: vern }
      end
    end

    def update_synonym(taxon_id, canonical)
      return unless @synonyms_hash.key?(canonical)

      @synonyms_hash[canonical].each do |syn|
        @synonyms << { taxon_id: taxon_id, name_string: syn[:name_string],
                       status: syn[:status] }
      end
    end

    def generate_dwca
      DwcaHunter.logger_write(object_id,
                              "Creating DarwinCore Archive file")
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
                "http://rs.tdwg.org/dwc/terms/scientificName",
                "http://rs.tdwg.org/dwc/terms/rank"]]
      @names.each do |n|
        @core << [n[:taxon_id], n[:name_string],
                  n[:rank]]
      end
      @eml = {
        id: @uuid,
        title: @title,
        authors: [],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
            email: "dmozzherin@gmail.com" }
        ],
        abstract: "Wikidata is a collaboratively edited multilingual " \
          "knowledge graph hosted by the Wikimedia Foundation. It is a " \
          "common source of open data that Wikimedia projects such as " \
          "Wikipedia, and anyone else, can use under the CC0 public domain " \
          "license. Wikidata is a wiki powered by the software MediaWiki, " \
          "including its extension for semi-structured data, the Wikibase.",
        url: "https://www.wikidata.org/wiki/Wikidata:Main_Page"
      }
      super
    end
  end
end
