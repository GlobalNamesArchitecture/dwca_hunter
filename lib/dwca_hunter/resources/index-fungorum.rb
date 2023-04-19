# frozen_string_literal: true

module DwcaHunter
  class ResourceAOS < DwcaHunter::Resource
    def initialize(opts = {})
      @command = "index-fungorum"
      @title = "Index Fungorum (Species Fungorum)"
      @url = "https://uofi.box.com/shared/static/rtfpkmfcuihwyryot8ur4fiad5jkkz8u.csv"
      @UUID = "af06816a-0b28-4a09-8219-bd1d63289858"
      @download_path = File.join(Dir.tmpdir,
                                 "dwca_hunter",
                                 "index-fungorum",
                                 "data.csv")
      @synonyms = []
      @names = []
      @extensions = []
      @synonyms_hash = {}
      super(opts)
    end

    def download
      puts "Downloading csv from remote"
      `curl -s -L #{@url} -o #{@download_path}`
    end

    def unpack; end

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

    def collect_names
      @names_index = {}
      file = CSV.open(File.join(@download_dir, "data.csv"),
                      headers: true)
      file.each_with_index do |row, _i|
        taxon_id = row["RECORD NUMBER"]
        current_id = row["CURRENT NAME RECORD NUMBER"]
        name_string = row["NAME OF FUNGUS"]
        authors = row["AUTHORS"]
        year = row["YEAR OF PUBLICATION"]
        kingdom = row["Kingdom name"]
        phylum = row["Phylum name"]
        sub_phylum = row["Subphylum name"]
        klass = row["Class name"]
        subklass = row["Subclass name"]
        order = row["Order name"]
        family = row["Family name"]
        code = "ICN"

        @names << {
          taxon_id: taxon_id,
          name_string: "#{name_string} #{authors} #{year}",
          current_id: current_id,
          kingdom: kingdom,
          phylum: phylum,
          klass: klass,
          order: order,
          family: family,
          code: code
        }
      end
    end

    def generate_dwca
      DwcaHunter.logger_write(object_id,
                              "Creating DarwinCore Archive file")
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
                "http://rs.tdwg.org/dwc/terms/scientificName",
                "http://rs.tdwg.org/dwc/terms/acceptedNameUsageID",
                "http://rs.tdwg.org/dwc/terms/kingdom",
                "http://rs.tdwg.org/dwc/terms/phylum",
                "http://rs.tdwg.org/dwc/terms/class",
                "http://rs.tdwg.org/dwc/terms/order",
                "http://rs.tdwg.org/dwc/terms/family",
                "http://rs.tdwg.org/dwc/terms/nomenclaturalCode"]]
      @names.each do |n|
        @core << [n[:taxon_id], n[:name_string], n[:current_id],
                  n[:kingdom], n[:phylum], n[:klass], n[:order], n[:family],
                  n[:code]]
      end

      @eml = {
        id: @uuid,
        title: @title,
        authors: [
          { first_name: "Paul",
            last_name: "Kirk" }
        ],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
            email: "dmozzherin@gmail.com" }
        ],
        abstract: "The Index Fungorum, the global fungal nomenclator " \
          "coordinated and supported by the Index Fungorum Partnership, " \
          "contains names of fungi (including yeasts, lichens, chromistan " \
          "fungal analogues, protozoan fungal analogues and fossil forms) " \
          "at all ranks.\n\n" \
          "As a result of changes to the ICN (previously ICBN) relating to " \
          "registration of names and following the lead taken by MycoBank, " \
          "Index Fungorum now provides a mechanism to register names of " \
          "new taxa, new names, new combinations and new typifications — no " \
          "login is required. Names registered at Index Fungorum can be " \
          "published immediately through the Index Fungorum e-Publication " \
          "facility — an authorized login is required for this.\n\n" \
          "Species Fungorum is currently an RBG Kew coordinated initiative " \
          "to compile a global checklist of the fungi. You may search " \
          "systematically defined and taxonomically complete datasets - " \
          "global species databases - or the entire Species Fungorum. " \
          "Species Fungorum contributes the fungal component to the Species " \
          "2000 project and, in partnership with ITIS, to the Catalogue " \
          "of Life (currently used in the GBIF and EoL portal); for more " \
          "information regarding these global initiative visit their " \
          "websites. Please contact Paul Kirk if you you would like to " \
          "contribute to Species Fungorum.",
        url: @url
      }
      super
    end
  end
end