module OGR
  class ShpWriter < Writer
    include OGR::FFIOGR

    def initialize
      OGRRegisterAll()
      @driver = OGRGetDriverByName("ESRI Shapefile")
    end
  end
end
