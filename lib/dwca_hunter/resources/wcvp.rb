# frozen_string_literal: true

module DwcaHunter
  class ResourceWorldVascPlants < DwcaHunter::Resource
    def initialize(opts = { download: true })
      @parser = Biodiversity::Parser
      @command = "wcvp"
      @title = "The World Checklist of Vascular Plants"
      @url = "http://sftp.kew.org/pub/data-repositories/WCVP/wcvp_v7_dec_2021.zip"
      @UUID = "814d1a77-2234-449b-af4a-138e0e1b1326"
      @download_dir = File.join(Dir.tmpdir, "dwca_hunter", "wcvp")
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
      puts("Check for newer version at http://sftp.kew.org/pub/data-repositories/WCVP/")
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
      res << vern if vern != ""
      verns = row["otherCommonNames"].to_s
      if verns != ""
        verns = verns.split("|")
        res += verns
      end
      res.map do |v|
        { taxon_id: id, vern: v, lang: "en" }
      end
    end

    def rank(name_string)
      res = ""
      parsed = @parser.parse(name_string)
      if parsed[:parsed]
        return "species" if parsed[:cardinality] == 2

        canonical = parsed[:canonical][:full]
        if !canonical.index(" subsp.").nil?
          return "subspecies"
        elsif !canonical.index(" f.").nil?
          return "forma"
        elsif !canonical.index(" var.").nil?
          return "variety"
        end

        puts name_string if parsed[:quality] != 1
      end
      res
    end

    def collect_names
      @names_index = {}
      file = CSV.open(File.join(@download_dir, find_csv_file),
                      headers: true, col_sep: "|", quote_char: "\b")
      file.each do |row|
        taxon_id = row["kew_id"]
        domain = "Plantae"
        phylum = "Tracheophyta"
        family = row["family"].to_s.strip
        genus = row["genus"].to_s.strip
        next if genus[0].upcase != genus[0]

        accepted_id = row["accepted_kew_id"].to_s.strip
        accepted_id = nil if accepted_id.empty?
        name_string = row["taxon_name"].to_s.strip
        next if name_string.strip.empty?

        authors = row["authors"].to_s.strip
        name_string = "#{name_string} #{authors}" unless authors.empty?
        taxonomic_status = row["taxonomic_status"].to_s.strip.downcase.gsub("_", " ")

        rank = row["rank"].to_s.strip.downcase
        rank = nil if rank.empty?

        @names << {
          taxon_id: taxon_id,
          domain: domain,
          phylum: phylum,
          family: family,
          genus: genus,
          current_id: accepted_id,
          name_string: name_string,
          taxonomic_status: taxonomic_status,
          rank: rank,
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
                "http://rs.tdwg.org/dwc/terms/family",
                "http://rs.tdwg.org/dwc/terms/genus",
                "http://rs.tdwg.org/dwc/terms/taxonRank",
                "http://rs.tdwg.org/dwc/terms/taxonomicStatus",
                "http://rs.tdwg.org/dwc/terms/nomenclaturalCode"]]
      @names.each do |n|
        @core << [n[:taxon_id], n[:name_string], n[:current_id],
                  n[:domain], n[:phylum], n[:family],
                  n[:genus], n[:rank], n[:taxonomic_status], n[:nom_code]]
      end

      @eml = {
        id: @uuid,
        title: @title,
        authors: [
          {
            first_name: "Rafaël",
            last_name: "Govaerts"
          },
          {
            first_name: "Eimear",
            middle_name: "Nic",
            last_name: "Lughadha"
          },
          {
            first_name: "Nicholas",
            last_name: "Black"
          },
          {
            first_name: "Robert",
            last_name: "Turner"
          },
          {
            first_name: "Alan",
            last_name: "Paton"
          }
        ],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
            email: "dmozzherin@gmail.com" }
        ],
        abstract: "The World Checklist of Vascular Plants (WCVP) " \
                  "is a comprehensive list of scientifically described " \
                  "plant species, compiled over four decades, " \
                  "from peer-reviewed literature, authoritative " \
                  "scientific databases, herbaria and observations, " \
                  "then reviewed by experts.",
        url: "https://wcvp.science.kew.org"
      }
      super
    end
  end
end
