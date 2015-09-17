module PlusCodes

  # [CodeArea] contains coordinates of a decoded Open Location Code(Plus+Codes).
  # The coordinates include the latitude and longitude of the lower left and
  # upper right corners and the center of the bounding box for the area the
  # code represents.
  # Attributes:
  #   latitude_lo: The latitude of the SW corner in degrees.
  #   longitude_lo: The longitude of the SW corner in degrees.
  #   latitude_hi: The latitude of the NE corner in degrees.
  #   longitude_hi: The longitude of the NE corner in degrees.
  #   latitude_center: The latitude of the center in degrees.
  #   longitude_center: The longitude of the center in degrees.
  #   code_length: The number of significant characters that were in the code.
  #
  # @author We-Ming Wu
  class CodeArea
    attr_accessor :south_latitude, :west_longitude, :latitude_height, :longitude_width,
      :latitude_center, :longitude_center

    # Creates a [CodeArea].
    #
    # @param latitude_lo [Numeric] the latitude of the SW corner in degrees
    # @param longitude_lo [Numeric] the longitude of the SW corner in degrees
    # @param latitude_hi [Numeric] the latitude of the NE corner in degrees
    # @param longitude_hi [Numeric] the longitude of the NE corner in degrees
    # @param code_length [Integer] the number of characters in the code, this excludes the separator
    # @return [CodeArea] a code area which contains the coordinates
    def initialize(south_latitude, west_longitude, latitude_height, longitude_width)
      @south_latitude = south_latitude
      @west_longitude = west_longitude
      @latitude_height = latitude_height
      @longitude_width = longitude_width
      @latitude_center = south_latitude + latitude_height / 2.0
      @longitude_center = west_longitude + longitude_width / 2.0
    end

    def north_latitude
      @south_latitude + @latitude_height
    end

    def east_longitude
      @west_longitude + @longitude_width
    end
  end

end
