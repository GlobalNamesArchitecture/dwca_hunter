# frozen_string_literal: true

module DwcaHunter
  class ResourceAlgaebase < DwcaHunter::Resource
    def initialize(opts = { download: true })
      @parser = Biodiversity::Parser
      @command = "algaebase"
      @title = "AlgaeBase"
      @url = "https://uofi.box.com/shared/static/lm7i6ppwdfnovshr9wrj5gbfpu7ej71g.csv"
      @UUID = "a5869bfb-7cbf-40f2-88d3-962922dac43f"
      @download_path = File.join(Dir.tmpdir,
        "dwca_hunter",
        "algaebase",
        "data.csv")
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
        return f if f[-4..-1] == ".csv"
      end
    end

    def assemble_synonym(row)
      name = row["originalNameCombination"].gsub("_", " ")
      auth = "#{row['authoritySpeciesAuthor']} #{row['aurhoritySpeciesYear']}".
        strip
      name = "#{name} #{auth}".strip
      { taxon_id: row["id"], name_string: name, status: "synonym" }
    end

    def vernaculars(row)
      id = row["id"]
      res = []
      vern = row["mainCommonName"].to_s
      res << vern  if vern != ""
      verns = row["otherCommonNames"].to_s
      if verns != ""
        verns = verns.split("|")
        res += verns
      end
      res.map do |v|
        { taxon_id: id, vern: v, lang: "en" }
      end
    end

    def clean(name)
      name = name.gsub(/(U|u)nkn?own authorit(y|ies)/, "")
      name = name.gsub(/(A|a)uthority unknown/, "")
      name = name.gsub(/(A|a)uthority not known/, "")
      name = name.gsub(/unknon authority/, "")
      name = name.gsub(/index$/, "")
      name = name.gsub("No authority known", "")
      name = name.gsub(/ mss$/, "")
      name = name.gsub(/ De toni/, " De Toni")
      name = name.gsub(/ Kolbei/, " kolbei")

      name = name.gsub(/Korsikovii/, "korsikovii")
      name = name.gsub(/Schilleri/, "schilleri")
      name = name.gsub(/Arnoldii/, "arnoldii")
      name = name.gsub(/Bublitachenkoi/, "bublitachenkoi")
      name = name.gsub(/J.-J./, "J.J.")
      name = name.gsub(/Himantidium/, "himantidium")
      name.strip
    end

    def rank(name_string) 
      res = ""
      parsed = @parser.parse(name_string)
      if parsed[:parsed]
        if parsed[:cardinality] == 2
          return "species"
        end

        canonical = parsed[:canonical][:full] 
        if !canonical.index(" subsp.").nil?
          return "subspecies"
        elsif !canonical.index(" f.").nil?
          return "forma"
        elsif !canonical.index(" var.").nil?
          return "variety"
        end
        
        if parsed[:quality] != 1
          puts name_string
        end
      end
      res
    end

    def collect_names
      @names_index = {}
      file = CSV.open(File.join(@download_dir, find_csv_file),
        headers: true)
      file.each do |row|
        domain = row["Domain"].to_s.strip
        domain = nil if domain.match(/incertae/) || domain.empty?
        phylum = row["Division"].to_s.strip
        phylum = nil if phylum.match(/incertae/) || phylum.empty?
        klass = row["Class"].to_s.strip
        klass = nil if klass.match(/incertae/) || klass.empty?
        order = row["Order"].to_s.strip
        order = nil if order.match(/incertae/) || order.empty?
        family = row["Family"].to_s.strip
        family = nil if family.match(/incertae/) || family.empty?
        genus = row["Genus"].to_s.strip
        genus = nil if genus.match(/incertae/) || genus.empty?
        accepted_id = row["AcceptedId"].to_s.strip
        accepted_id = nil if accepted_id.empty?
        taxon_id = row["LocalId"]
        name_string = row["NameString"].to_s.strip
        next if name_string.strip.empty?

        name_string = clean(name_string)
        
        @names << {
          taxon_id: taxon_id,
          domain: domain,
          phylum: phylum,
          klass: klass,
          order: order,
          family: family,
          genus: genus,
          current_id: accepted_id,
          name_string: name_string,
          rank: rank(name_string),
          nom_code: "ICN"
        }
      end
    end

    def generate_dwca
      DwcaHunter.logger_write(object_id, "Creating DarwinCore Archive file")
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
                "http://rs.tdwg.org/dwc/terms/scientificName",
                "http://rs.tdwg.org/dwc/terms/acceptedNameUsageID",
                "http://rs.tdwg.org/dwc/terms/domain",
                "http://rs.tdwg.org/dwc/terms/phylum",
                "http://rs.tdwg.org/dwc/terms/class",
                "http://rs.tdwg.org/dwc/terms/order",
                "http://rs.tdwg.org/dwc/terms/family",
                "http://rs.tdwg.org/dwc/terms/genus",
                "http://rs.tdwg.org/dwc/terms/taxonRank",

                "http://rs.tdwg.org/dwc/terms/nomenclaturalCode"]]
      @names.each do |n|
        @core << [n[:taxon_id], n[:name_string], n[:current_id],
                  n[:domain], n[:phylum], n[:klass], n[:order], n[:family],
                  n[:genus], n[:rank], n[:nom_code]]
      end

      @eml = {
        id: @uuid,
        title: @title,
        authors: [
          { first_name: "Michael",
            last_name: "Guiry" }
        ],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
            email: "dmozzherin@gmail.com" }
        ],
        abstract: "AlgaeBase is a global algal database of taxonomic, " \
                  "nomenclatural and distributional information.",
        url: "https://www.algaebase.org"
      }
      super
    end
  end
end
