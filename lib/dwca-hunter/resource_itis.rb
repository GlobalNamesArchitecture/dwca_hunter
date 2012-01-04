# encoding: utf-8
class DwcaHunter
  class ResourceITIS < DwcaHunter::Resource
    def initialize(opts = {})
      @title = "ITIS"
      @url = "http://www.itis.gov/downloads/itisMySQLTables.tar.gz"
      @uuid =  "5d066e84-e512-4a2f-875c-0a605d3d9f35"
      @download_path = File.join(DEFAULT_TMP_DIR, "dwca_hunter", "itis", "data.tar.gz")
      @conv = Iconv.new('UTF-8', 'ISO-8859-1')
      @ranks = {} 
      @kingdoms = {}
      @authors = {}
      @vernaculars = {}
      @synonyms = {}
      @synonym_of = {}
      @names = {}
      @extensions = []
      super(opts)
      @itis_dir = File.join(@download_dir, 'itis')
    end

    def unpack
      unpack_tar
      dir = Dir.entries(@download_dir).select {|e| e.match /itisMySQL/}[0]
      FileUtils.mv(File.join(@download_dir, dir), @itis_dir)
    end

    def make_dwca
      DwcaHunter::logger_write(self.object_id, "Extracting data")
      get_ranks
      get_kingdoms
      get_authors
      get_vernaculars
      get_synonyms
      get_names
      generate_dwca
    end

  private
    def get_ranks
      # 0    kingdom_id integer not null
      # 1    rank_id smallint not null
      # 2    rank_name char(15) not null
      # 3    dir_parent_rank_id smallint not null
      # 4    req_parent_rank_id smallint not null
      # 5    update_date date not null
      rank_file = File.join(@itis_dir, 'taxon_unit_types')
      f = open(rank_file, "r:utf-8")
      f.each do |l|
        l = @conv.iconv(l)
        row = l.strip.split("|")
        @ranks[row[1].strip] = row[2].strip
      end
    end

    def get_kingdoms
      # 0    kingdom_id serial not null
      # 1    kingdom_name char(10) not null
      # 2    update_date date not null

      f = open(File.join(@itis_dir, 'kingdoms'))
      f.each do |l|
        data = l.strip.split("|")
        @kingdoms[data[0].strip] = data[1].strip
      end
    end

    def get_authors
      # 0    taxon_author_id serial not null
      # 1    taxon_author varchar(100,30) not null
      # 2    update_date date not null
      # 3    kingdom_id smallint not null

      f = open(File.join(@itis_dir, 'taxon_authors_lkp'))
      f.each do |l|
        l = @conv.iconv(l)
        data = l.strip.split("|")
        @authors[data[0].strip] = data[1].strip
      end
    end

    def get_vernaculars
      # 0    tsn integer not null
      # 1    vernacular_name varchar(80,5) not null
      # 2    language varchar(15) not null
      # 3    approved_ind char(1)
      # 4    update_date date not null
      # 5    primary key (tsn,vernacular_name,language)  constraint "itis".vernaculars_key
       
      f = open(File.join(@itis_dir, 'vernaculars'))
      f.each_with_index do |l, i|
        DwcaHunter::logger_write(self.object_id, "Extracted %s vernacular names" % i) if i % BATCH_SIZE == 0
        l = @conv.iconv(l)
        data = l.split("|").map { |d| d.strip }
        name_tsn = data[0]
        string   = data[1]
        language = data[2]
        language = "Common name" if language == "unspecified"
        @vernaculars[name_tsn] = { name:string, language:language }
      end
    end

    def get_synonyms
      # 0    tsn integer not null
      # 1    tsn_accepted integer not null
      # 2    update_date date not null
      
      f = open(File.join(@itis_dir, 'synonym_links'))
      f.each_with_index do |l, i|
        DwcaHunter::logger_write(self.object_id, "Extracted %s synonyms" % i) if i % BATCH_SIZE == 0
        l = @conv.iconv(l)
        data = l.split("|").map { |d| d.strip }
        synonym_name_tsn = data[0]
        accepted_name_tsn = data[1]
        @synonyms[synonym_name_tsn] = accepted_name_tsn
      end
    end

    def get_names
      # 0    tsn serial not null
      # 1    unit_ind1 char(1)
      # 2    unit_name1 char(35) not null
      # 3    unit_ind2 char(1)
      # 4    unit_name2 varchar(35)
      # 5    unit_ind3 varchar(7)
      # 6    unit_name3 varchar(35)
      # 7    unit_ind4 varchar(7)
      # 8    unit_name4 varchar(35)
      # 9    unnamed_taxon_ind char(1)
      # 10   usage varchar(12,5) not null
      # 11   unaccept_reason varchar(50,9)
      # 12   credibility_rtng varchar(40,17) not null
      # 13   completeness_rtng char(10)
      # 14   currency_rating char(7)
      # 15   phylo_sort_seq smallint
      # 16   initial_time_stamp datetime year to second not null
      # 17   parent_tsn integer
      # 18   taxon_author_id integer
      # 19   hybrid_author_id integer
      # 20   kingdom_id smallint not null
      # 21   rank_id smallint not null
      # 22   update_date date not null
      # 23   uncertain_prnt_ind char(3)
      
      f = open(File.join(@itis_dir, 'taxonomic_units'))
      f.each_with_index do |l, i|
        DwcaHunter::logger_write(self.object_id, "Extracted %s names" % i) if i % BATCH_SIZE == 0
        l = @conv.iconv(l)
        data = l.split("|").map { |d| d.strip }
        name_tsn   = data[0]
        x1         = data[1]
        name_part1 = data[2]
        x2         = data[3]
        name_part2 = data[4]
        sp_marker1 = data[5]
        name_part3 = data[6]
        sp_marker2 = data[7]
        name_part4 = data[8]
        status     = data[10]
        parent_tsn = data[17]
        author_id  = data[18]
        rank_id    = data[21]

        parent_tsn = 0 if parent_tsn == ''
        name = [x1, name_part1, x2, name_part2, sp_marker1, name_part3, sp_marker2, name_part4].join(' ').strip.gsub(/\s+/, ' ')
        name << " #{@authors[author_id]}" if(@authors[author_id]) 
        rank = @ranks[rank_id] ? @ranks[rank_id] : ''
        @names[name_tsn] = { name:name, status:status, parent_tsn:parent_tsn, rank:rank } 
      end
    end

    def generate_dwca
      DwcaHunter::logger_write(self.object_id, "Creating DarwinCore Archive file")
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
        "http://purl.org/dc/terms/parentNameUsageID",
        "http://rs.tdwg.org/dwc/terms/acceptedNameUsageID",
        "http://purl.org/dc/terms/scientificName",
        "http://rs.tdwg.org/dwc/terms/taxonomicStatus",
        "http://purl.org/dc/terms/taxonRank"]]
      @extensions << { :data => [["http://rs.tdwg.org/dwc/terms/taxonID",
        "http://rs.tdwg.org/dwc/terms/vernacularName",
        "http://purl.org/dc/terms/language"]], :file_name => "vernacular_names.txt" }
      @names.keys.each_with_index do |k, i|
        d = @names[k]
        accepted_id = @synonyms[k] ? @synonyms[k] : nil
        parent_id = d[:parent_tsn].to_i == 0 ? nil : d[:parent_tsn]
        row = [k, parent_id, accepted_id, d[:name], d[:status], d[:rank]]
        @core << row
      end

      @vernaculars.keys.each_with_index do |k, i|
        d = @vernaculars[k]
        @extensions[0][:data] << [k, d[:name], d[:language]]
      end

      @eml = {
          :id => @uuid,
          :title => @title,
          :authors => [
            {:email => "itiswebmaster@itis.gov"}
          ],
          :metadata_providers => [
            { :first_name => 'Dmitry',
              :last_name => 'Mozzherin',
              :email => 'dmozzherin@gmail.com' }
            ],
          :abstract => "The White House Subcommittee on Biodiversity and Ecosystem Dynamics has identified systematics as a research priority that is fundamental to ecosystem management and biodiversity conservation. This primary need identified by the Subcommittee requires improvements in the organization of, and access to, standardized nomenclature. ITIS (originally referred to as the Interagency Taxonomic Information System) was designed to fulfill these requirements. In the future, the ITIS will provide taxonomic data and a directory of taxonomic expertise that will support the system",
          :url => 'http://www.itis.gov'
      }
      super
    end
  end
end


