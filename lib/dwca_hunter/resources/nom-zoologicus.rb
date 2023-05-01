# frozen_string_literal: true
require 'find'

module DwcaHunter
  class ResourceNomZoologicus < DwcaHunter::Resource
    def initialize(opts = { download: false, unpack: false })
      @parser = Biodiversity::Parser
      @command = "nom-zoologicus"
      @title = "Nomenclator Zoologicus"
      @url = "https://zenodo.org/record/7013826/files/rdmpage/nomenclator-zoologicus-coldp-v0.2.1.zip?download=1"
      @UUID = "02fd9b10-78e4-43a5-889e-0639a771c576
"
      @download_path = File.join(Dir.tmpdir,
                                 "dwca_hunter",
                                 "nom-zoologicus",
                                 "data.zip")
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
      self.class.unzip(@download_path, @download_dir)
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
      Find.find(@download_dir).each do |f|
        return f if f.end_with? "names.tsv"
      end
    end

    def collect_names
      @names_index = {}
      file = CSV.open(find_csv_file,
                      headers: true, col_sep: "\t", quote_char: "\b")
      file.each do |row|
        taxon_id = row["ID"].to_s.strip
        rank = row["rank"].strip
        nom_code = row["code"].strip
        name_string = row["scientificName"]
        authorship = row["authorship"]
        next if name_string.strip.empty?
        name_full = [name_string, authorship].join(' ')

        @names << {
          taxon_id: taxon_id,
          name_string: name_full.strip,
          rank: rank,
          nom_code: nom_code
        }
      end
    end

    def generate_dwca
      DwcaHunter.logger_write(object_id, "Creating DarwinCore Archive file")
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
                "http://rs.tdwg.org/dwc/terms/scientificName",
                "http://rs.tdwg.org/dwc/terms/taxonRank",
                "http://rs.tdwg.org/dwc/terms/nomenclaturalCode"]]
      @names.each do |n|
        @core << [n[:taxon_id], n[:name_string], n[:rank], n[:nom_code]]
      end

      @eml = {
        id: @uuid,
        title: @title,
        authors: [
          { first_name: "David",
            last_name: "Remsen" },
          { first_name: "Cathy",
            last_name: "Norton" },
          { first_name: "David",
            last_name: "Patterson" }
        ],
        metadata_providers: [
          { first_name: "Roderic",
            last_name: "Page",
            email: "Roderic.Page@glasgow.ac.uk" }
        ],
        abstract: "Nomenclator Zoologicus is a catalog of the bibliographic " \
                  "origins of the names of every genus and subgenus in the " \
                  "published literature since the tenth edition of " \
                  "Linnaeus' System Natureae in 1758 (Linnæus, 1758) up " \
                  "to 1994. An estimated 340,000 genera are represented " \
                  "in the text and there are approximately 3000 " \
                  "supplemental corrections. It provides a nucleus of core " \
                  "genera data and is recognized as an essential reference " \
                  "document by the zoological taxonomic community.",
        url: "https://doi.org/10.5281/zenodo.7010676"
      }
      super
    end
  end
end
