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
    attr_accessor :latitude_lo, :longitude_lo, :latitude_hi, :longitude_hi,
      :code_length, :latitude_center, :longitude_center

    # Creates a [CodeArea].
    #
    # @param latitude_lo [Numeric] the latitude of the SW corner in degrees
    # @param longitude_lo [Numeric] the longitude of the SW corner in degrees
    # @param latitude_hi [Numeric] the latitude of the NE corner in degrees
    # @param longitude_hi [Numeric] the longitude of the NE corner in degrees
    # @param code_length [Integer] the number of characters in the code, this excludes the separator
    # @return [CodeArea] a code area which contains the coordinates
    def initialize(latitude_lo, longitude_lo, latitude_hi, longitude_hi, code_length)
      @latitude_lo = latitude_lo
      @longitude_lo = longitude_lo
      @latitude_hi = latitude_hi
      @longitude_hi = longitude_hi
      @code_length = code_length
      @latitude_center = [@latitude_lo + (@latitude_hi - @latitude_lo) / 2, LATITUDE_MAX].min
      @longitude_center = [@longitude_lo + (@longitude_hi - @longitude_lo) / 2, LONGITUDE_MAX].min
    end

    def to_s
      "lat_lo: #{@latitude_lo} long_lo: #{@longitude_lo} lat_hi: #{@latitude_hi} long_hi: #{@longitude_hi} code_len: #{@code_length}"
    end
  end

end
