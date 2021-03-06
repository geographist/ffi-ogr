module OGR
  class Polygon < Geometry
    def self.create(rings)
      polygon = OGR::Tools.cast_geometry(FFIOGR.OGR_G_CreateGeometry(:polygon))

      rings.each do |ring|
        lr = LinearRing.create(ring)
        polygon.add_geometry(lr)
      end

      polygon
    end
  end
end
