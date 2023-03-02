# frozen_string_literal: true

module DwcaHunter
  class ResourceLeipzigPlantCat < DwcaHunter::Resource
    def initialize(opts = { download: true })
      @parser = Biodiversity::Parser
      @command = "lcvp"
      @title = "The Leipzig Catalogue of Vascular Plants"
      @url = "https://github.com/idiv-biodiversity/LCVP/raw/master/raw_data_LCVP/LCVP_104.zip"
      @UUID = "75fb6846-4c37-4b45-a2ab-05dc0124957b"
      @download_dir = File.join(Dir.tmpdir, "dwca_hunter", "lcvp")
      @download_path = File.join(@download_dir, "data.zip")
      @synonyms = []
      @names = []
      @vernaculars = []
      @extensions = []
      @synonyms_hash = {}
      @vernaculars_hash = {}
      @ids = {}
      super(opts)
    end

    def download
      puts("Check for newer version at https://github.com/idiv-biodiversity/LCVP")
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

    def gnid(str)
      "gn-#{GnUUID.uuid(str)[0..12]}"
    end

    def collect_names
      @names_index = {}
      latin1 = File.read(File.join(@download_dir, find_csv_file))
      w = File.open(File.join(@download_dir, "data.tsv"), "w:utf-8")
      w.write(latin1.force_encoding("iso-8859-1").encode("UTF-8"))
      w.close
      file = CSV.open(File.join(@download_dir, "data.tsv"),
                      headers: true, col_sep: "\t", quote_char: "\b")
      file.each do |row|
        name_string = row["Input Taxon"].to_s.strip
        taxon_id = gnid(name_string)
        domain = "Plantae"
        phylum = "Tracheophyta"
        order = row["Order"]
        family = row["Family"].to_s.strip
        accepted_name = row["Output Taxon"].to_s.strip
        accepted_id = gnid(accepted_name)
        taxonomic_status = row["Status"].to_s.strip

        next if taxonomic_status != "accepted" && taxon_id == accepted_id

        @ids[taxon_id] = true
        @names << {
          taxon_id: taxon_id,
          domain: domain,
          phylum: phylum,
          order: order,
          family: family,
          current_id: accepted_id,
          current_name: accepted_name,
          name_string: name_string,
          taxonomic_status: taxonomic_status,
          nom_code: "ICN"
        }
      end
      add_missing
    end

    def add_missing
      names = []
      @names.each do |n|
        next if @ids.key?(n[:current_id])

        @ids[n[:current_id]] = true
        puts n[:current_name]
        names << {
          taxon_id: n[:current_id],
          domain: n[:domain],
          phylum: n[:phylum],
          order: n[:order],
          family: n[:family],
          current_id: n[:current_id],
          current_name: n[:current_name],
          name_string: n[:current_name],
          taxonomic_status: "accepted",
          nom_code: "ICN"
        }
      end
      @names += names
    end

    def generate_dwca
      DwcaHunter.logger_write(object_id, "Creating DarwinCore Archive file")
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
                "http://rs.tdwg.org/dwc/terms/scientificName",
                "http://rs.tdwg.org/dwc/terms/acceptedNameUsageID",
                "http://rs.tdwg.org/dwc/terms/domain",
                "http://rs.tdwg.org/dwc/terms/phylum",
                "http://rs.tdwg.org/dwc/terms/order",
                "http://rs.tdwg.org/dwc/terms/family",
                "http://rs.tdwg.org/dwc/terms/taxonomicStatus",
                "http://rs.tdwg.org/dwc/terms/nomenclaturalCode"]]
      @names.each do |n|
        @core << [n[:taxon_id], n[:name_string], n[:current_id],
                  n[:domain], n[:phylum], n[:order], n[:family],
                  n[:taxonomic_status], n[:nom_code]]
      end

      @eml = {
        id: @uuid,
        title: @title,
        authors: [
          {
            first_name: "Martin",
            last_name: "Freiberg"
          },
          {
            first_name: "Marten",
            last_name: "Winter"
          },
          {
            first_name: "Alessandro",
            last_name: "Gentile"
          },
          {
            first_name: "Alexander",
            last_name: "Zizka"
          },
          {
            first_name: "Alexandra",
            last_name: "Muellner-Riehl"
          },
          {
            first_name: "Alexandra",
            last_name: "Weigelt"
          },
          {
            first_name: "Christian",
            last_name: "Wirth"
          }
        ],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
            email: "dmozzherin@gmail.com" }
        ],
        abstract: "LCVP, The Leipzig catalogue of vascular plants, " \
        "a new taxonomic reference list for all known vascular plants",
        url: "https://github.com/idiv-biodiversity/LCVP"
      }
      super
    end
  end
end
