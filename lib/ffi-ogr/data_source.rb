module OGR
  class DataSource
    include FFIOGR

    attr_accessor :ptr

    def initialize(ptr)
      @ptr = FFI::AutoPointer.new(ptr, self.class.method(:release))
      #@ptr = FFI::AutoPointer.new(ptr)
      @ptr.autorelease = false
    end

    def self.release(ptr);end

    def free
      FFIOGR.OGR_DS_Destroy(@ptr)
    end

    def to_hash
      h = {
        layers: []
      }

      layers.each do |layer|
        name = layer.name
        geometry_type = layer.geometry_type
        spatial_reference = layer.spatial_ref.to_proj4
        features = []

        layer.features.each do |feature|
          fields = feature.fields
          geometry = OGR::Tools.cast_geometry(feature.geometry).to_geojson
          features << {fields: fields, geometry: geometry}
        end

        h[:layers] << {
          name: name,
          geometry_type: geometry_type,
          spatial_reference: spatial_reference,
          features: features
        }
      end

      h
    end

    def copy(output_type, output_path, spatial_ref=nil)
      writer = OGR::GenericWriter.new(OGR::DRIVER_TYPES[output_type.downcase])
      writer.set_output(output_path)
      out = writer.ptr

      layers.each do |layer|
        name = layer.name
        geometry_type = layer.geometry_type
        old_sr = layer.spatial_ref

        ct = OGR::CoordinateTransformation.find_transformation(old_sr, spatial_ref) unless spatial_ref.nil? || (spatial_ref == old_sr)

        sr = spatial_ref.nil? ? nil : spatial_ref.ptr
        new_layer = out.add_layer name, geometry_type, sr

        ptr = layer.ptr

        layer_definition = FFIOGR.OGR_L_GetLayerDefn(ptr)
        field_count = FFIOGR.OGR_FD_GetFieldCount(layer_definition)

        for i in (0...field_count)
          fd = FFIOGR.OGR_FD_GetFieldDefn(layer_definition, i)
          name = FFIOGR.OGR_Fld_GetNameRef(fd)
          type = FFIOGR.OGR_Fld_GetType(fd)

          new_layer.add_field name, type
        end

        layer.features.each do |feature|
          geometry = OGR::Tools.cast_geometry(feature.geometry)
          geometry.transform ct if ct

          new_feature = new_layer.create_feature
          new_feature.add_geometry geometry

          ptr = feature.ptr
          field_count = FFIOGR.OGR_F_GetFieldCount(ptr)

          for i in (0...field_count)
            fd = FFIOGR.OGR_F_GetFieldDefnRef(ptr, i)
            field_name = FFIOGR.OGR_Fld_GetNameRef(fd)
            field_type = FFIOGR.OGR_Fld_GetType(fd)

            case field_type
            when :integer
              field_value = FFIOGR.OGR_F_GetFieldAsInteger(ptr, i)
            when :real
              field_value = FFIOGR.OGR_F_GetFieldAsDouble(ptr, i)
            else
              field_value = FFIOGR.OGR_F_GetFieldAsString(ptr, i)
            end

            new_feature.set_field_value field_name, field_value, field_type
          end

          new_layer.add_feature new_feature
        end

        new_layer.sync
      end
    end

    def add_layer(name, geometry_type, spatial_ref=nil, options={})
      # TODO: add options as StringList ...
      layer = FFIOGR.OGR_DS_CreateLayer(@ptr, name, spatial_ref, geometry_type.to_sym, nil)
      OGR::Tools.cast_layer(layer)
    end

    def num_layers
      FFIOGR.OGR_DS_GetLayerCount(@ptr)
    end

    def get_layers
      layers = []

      for i in (0...num_layers) do
        layers << OGR::Tools.cast_layer(OGR_DS_GetLayer(@ptr, i))
      end

      layers
    end
    alias_method :layers, :get_layers

    def get_features
      layers.map {|l| l.features}
    end
    alias_method :features, :get_features

    def get_geometries(as_geojson=false)
      unless as_geojson
        features.map {|feature| feature.map {|f| OGR::Tools.cast_geometry(f.geometry)}}
      else
        features.map {|feature| feature.map {|f| OGR::Tools.cast_geometry(f.geometry).to_geojson}}
      end
    end
    alias_method :geometries, :get_geometries

    def get_fields
      features.map {|feature| feature.map {|f| f.fields}}
    end
    alias_method :fields, :get_fields

    def to_shp(output_path, spatial_ref=nil)
      raise RuntimeError.new("Output path not specified.") if output_path.nil?
      copy('shapefile', output_path, spatial_ref)
    end

    def to_geojson(output_path, spatial_ref=nil)
      raise RuntimeError.new("Output path not specified.") if output_path.nil?
      copy('geojson', output_path, spatial_ref)
    end

    def to_json(pretty=false)
      h = {
        type: 'FeatureCollection',
        bbox: nil,
        features: []
      }

      layers.each do |layer|
        h[:bbox] = layer.envelope.to_a true
        geometry_type = layer.geometry_type.to_s.capitalize

        layer.features.each do |feature|
          properties = feature.fields
          geometry = OGR::Tools.cast_geometry(feature.geometry).to_geojson
          h[:features] << {type: geometry_type, geometry: geometry, properties: properties}
        end
      end

      unless pretty
        MultiJson.dump(h)
      else
        MultiJson.dump(h, pretty: true)
      end
    end
  end
end
