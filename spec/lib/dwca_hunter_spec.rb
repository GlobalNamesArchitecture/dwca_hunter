describe DwcaHunter do
  describe ".version" do
    it "returns the current version" do
      expect(subject.version).to match(/\d+\.\d+\.\d+/)
    end
  end

  describe ".resources" do
    it "finds registered resources" do
      res = subject.resources
      expect(res.size).to be == 13
    end
  end
end
