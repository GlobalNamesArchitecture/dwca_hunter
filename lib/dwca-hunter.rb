class DwcaHunter
  def initialize(resource)
    @resource = resource
  end
  
  def process
    download 
  end

private
  def download
    url = @resource.url
  end
end
