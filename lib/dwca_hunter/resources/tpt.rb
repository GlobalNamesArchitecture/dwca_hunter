# frozen_string_literal: true

module DwcaHunter
  class ResourceParasiteTracker < DwcaHunter::Resource
    def initialize(opts = { download: true, unpack: true })
      @parser = Biodiversity::Parser
      @command = "tpt"
      @title = "The Terrestrial Parasite Tracker"
      @url = "https://github.com/njdowdy/tpt-taxonomy/archive/refs/heads/main.zip"
      @UUID = "75886826-50f9-4513-916d-3ab4875cb063"
      @download_dir = File.join(Dir.tmpdir, "dwca_hunter", "tpt")
      @download_path = File.join(@download_dir, "data.zip")
      @synonyms = []
      @names = []
      @vernaculars = []
      @extensions = []
      @synonyms_hash = {}
      @vernaculars_hash = {}
      super(opts)
    end

    def download
      DwcaHunter.logger_write(object_id, "Downloading")
      `curl -s -L #{@url} -o #{@download_path}`
    end

    def unpack
      unpack_zip
    end

    def make_dwca
      DwcaHunter.logger_write(object_id, "Extracting data")
      get_names
      generate_dwca
    end

    private

    def get_names
      Dir.chdir(@download_dir)
      collect_names
    end

    def find_csv_file
      Dir.chdir(@download_dir)
      Dir.entries(".").each do |f|
        return f if f[-4..-1] == ".txt"
      end
    end

    def collect_names
      tpt_dir = "tpt-taxonomy-main"
      tpt_path = File.join(@download_dir, tpt_dir)
      @names_index = {}
      files = Dir.entries(tpt_path)
      count = 0
      files.each do |f|
        next unless f[-16..] == "standardized.csv"

        if ["siphonaptera-standardized.csv", "ixodes-standardized.csv"].include? f
          Encoding.latin1_to_utf8(File.join(tpt_path, f))
          f = "#{f}.utf_8"
        end

        puts "FILE: #{f}"

        file = CSV.open(File.join(@download_dir, tpt_dir, f), headers: true)
        file.each do |row|
          count += 1
          taxon_id = "gn_#{count}"
          kingdom = row["kingdom"].to_s.strip
          phylum = row["phylum"].to_s.strip
          klass = row["class"].to_s.strip
          order = row["order"].to_s.strip
          family = row["family"].to_s.strip
          genus = row["genus"].to_s.strip
          rank = row["taxonRank"].to_s.strip
          name_string = row["scientificName"].to_s.strip
          next if name_string.strip.empty?

          taxonomic_status = row["taxonomic_status"].to_s.strip.downcase.gsub("_", " ")

          @names << {
            taxon_id: taxon_id,
            kingdom: kingdom,
            phylum: phylum,
            klass: klass,
            order: order,
            family: family,
            genus: genus,
            name_string: name_string,
            taxonomic_status: taxonomic_status,
            rank: rank,
            nom_code: "ICZN"
          }
        end
      end
    end

    def generate_dwca
      DwcaHunter.logger_write(object_id, "Creating DarwinCore Archive file")
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
                "http://rs.tdwg.org/dwc/terms/scientificName",
                "http://rs.tdwg.org/dwc/terms/kingdom",
                "http://rs.tdwg.org/dwc/terms/phylum",
                "http://rs.tdwg.org/dwc/terms/class",
                "http://rs.tdwg.org/dwc/terms/order",
                "http://rs.tdwg.org/dwc/terms/family",
                "http://rs.tdwg.org/dwc/terms/genus",
                "http://rs.tdwg.org/dwc/terms/taxonRank",
                "http://rs.tdwg.org/dwc/terms/taxonomicStatus",
                "http://rs.tdwg.org/dwc/terms/nomenclaturalCode"]]
      @names.each do |n|
        @core << [n[:taxon_id], n[:name_string], n[:kingdom], n[:phylum],
                  n[:klass], n[:order], n[:family], n[:genus], n[:rank],
                  n[:taxonomic_status], n[:nom_code]]
      end

      @eml = {
        id: @uuid,
        title: @title,
        authors: [
          {
            first_name: "Jennifer",
            last_name: " Zaspel"
          },
          {
            first_name: "Erika",
            last_name: "Tucker"
          },
          {
            first_name: "Nicolas",
            middle_name: "J.",
            last_name: "Dowdy"
          }
        ],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
            email: "dmozzherin@gmail.com" }
        ],
        abstract: "The goal of the Terrestrial Parasite Tracker (TPT) " \
                  "project is to mobilize and digitally capture vector " \
                  "and parasite collections to help build a picture of " \
                  "parasite host-association evolution, distributions, " \
                  "and the ecological interactions of disease vectors " \
                  "which will assist scientists, educators, land managers, " \
                  "and policy makers.",
        url: "https://github.com/njdowdy/tpt-taxonomy"
      }
      super
    end
  end
end
