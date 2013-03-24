module OGR
  module Tools
    class << self
      def cast_shapefile(shp_ptr, options={})
        options = {auto_free: true}.merge(options)
        raise RuntimeError.new("SHP pointer is NULL") if shp_ptr.null?
        Shapefile.new shp_ptr, options[:auto_free]
      end

      def cast_feature(f_ptr, options={})
        options = {auto_free: true}.merge(options)
        raise RuntimeError.new("Feature pointer is NULL") if f_ptr.null?
        Feature.new f_ptr, options[:auto_free]
      end

      def cast_geometry(geom_ptr, options={})
        options = {auto_free: true}.merge(options)
        raise RuntimeError.new("Geometry pointer is NULL") if geom_ptr.null?

        geom_type = FFIOGR.OGR_G_GetGeometryType(geom_ptr)

        klass = case geom_type
        when :wkb_point
          OGR::Point
        when :wkb_polygon
          OGR::Polygon
        end

        klass.new(geom_ptr, options[:auto_free])
      end
    end
  end
end