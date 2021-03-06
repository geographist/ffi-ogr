module OGR
  class Geometry
    attr_accessor :ptr

    def initialize(ptr)
      @ptr = FFI::AutoPointer.new(ptr, self.class.method(:release))
      #@ptr = FFI::AutoPointer.new(ptr)
      @ptr.autorelease = false
    end

    def self.release(ptr);end

    def free
      FFIOGR.OGR_G_DestroyGeometry(@ptr)
    end

    def self.from_geojson(geojson)
      if geojson.instance_of? String
        geojson = MultiJson.load(geojson)
      end

      coords = geojson['coordinates']

      case geojson['type']
      when 'Point'
        OGR::Point.create coords
      when 'LineString'
        OGR::LineString.create coords
      when 'Polygon'
        OGR::Polygon.create coords
      end
    end

    def self.create_empty(geometry_type)
      OGR::Tools.cast_geometry(FFIOGR.OGR_G_CreateGeometry(geometry_type))
    end

    def add_geometry(geometry)
      FFIOGR.OGR_G_AddGeometry(@ptr, geometry.ptr)
    end

    def add_geometry_directly(geometry)
      FFIOGR.OGR_G_AddGeometryDirectly(@ptr, geometry.ptr)
    end

    def add_point(coords)
      raise RuntimeError.new("Invalid coordinate(s) specified") unless coords.size >= 2
      x = Float(coords[0])
      y = Float(coords[1])
      z = Float(coords[2]) if coords.size >= 3

      unless z
        FFIOGR.OGR_G_AddPoint_2D(@ptr, x, y)
      else
        FFIOGR.OGR_G_AddPoint(@ptr, x, y, z)
      end
    end

    def set_point(coords, idx)
      raise RuntimeError.new("Invalid coordinate(s) specified") unless coords.size >= 2
      x = Float(coords[0])
      y = Float(coords[1])
      z = Float(coords[2]) if coords.size >= 3

      unless z
        FFIOGR.OGR_G_SetPoint_2D(@ptr, idx, x, y)
      else
        FFIOGR.OGR_G_SetPoint(@ptr, idx, x, y, z)
      end
    end

    def is_3d?
      !!(geometry_type.to_s =~ /_25d/)
    end

    def flatten
      FFIOGR.OGR_G_FlattenTo2D(@ptr)
    end

    def get_geometry_type
      FFIOGR.OGR_G_GetGeometryType(@ptr)
    end
    alias_method :geometry_type, :get_geometry_type

    def get_spatial_ref
      OGR::Tools.cast_spatial_reference(FFIOGR.OGR_G_GetSpatialReference(@ptr))
    end
    alias_method :spatial_ref, :get_spatial_ref

    def transform(ct)
      FFIOGR.OGR_G_Transform(@ptr, ct)
    end

    def get_length
      FFIOGR.OGR_G_Length(@ptr)
    end
    alias_method :length, :get_length

    def get_area
      FFIOGR.OGR_G_Area(@ptr)
    end
    alias_method :area, :get_area

    def get_boundary
      FFIOGR.OGR_G_Boundary(@ptr)
    end
    alias_method :boundary, :get_boundary

    def get_envelope
      envelope = FFI::MemoryPointer.new :pointer, 4
      FFIOGR.OGR_G_GetEnvelope(@ptr, envelope)
      OGR::Envelope.new(envelope.read_array_of_double(4))
    end
    alias_method :envelope, :get_envelope

    def to_geojson
      MultiJson.load(FFIOGR.OGR_G_ExportToJson(@ptr))
    end

    def to_kml(elevation=nil)
      elevation = String(elevation) unless elevation.nil?
      FFIOGR.OGR_G_ExportToKML(@ptr, elevation)
    end

    def to_gml
      FFIOGR.OGR_G_ExportToGML(@ptr)
    end
  end
end
