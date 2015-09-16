require 'plus_codes'
require 'plus_codes/code_area'

module PlusCodes

  # [OpenLocationCode] implements the Google Open Location Code(Plus+Codes) algorithm.
  #
  # @author We-Ming Wu
  class OpenLocationCode

    # Validates the given plus+codes.
    #
    # @param code [String] a plus+codes
    # @return [TrueClass, FalseClass] true if the code is valid, false otherwise
    def valid?(code)
      return false if code.nil? || code.length <= 1

      separator_index = code.index(SEPARATOR)
      # There must be a single separator at an even index and position should be < SEPARATOR_POSITION.
      return false if separator_index.nil? ||
        separator_index != code.rindex(SEPARATOR) ||
        separator_index > SEPARATOR_POSITION ||
        separator_index.odd?

      # We can have an even number of padding characters before the separator,
      # but then it must be the final character.
      if code.include?(PADDING)
        # Not allowed to start with them!
        return false if code.start_with?(PADDING)

        # There can only be one group and it must have even length.
        pad_match = /(#{PADDING}+)/.match(code).to_a
        return false if pad_match.length != 2
        match = pad_match[1]
        return false if match.length.odd? || match.length > SEPARATOR_POSITION - 2

        # If the code is long enough to end with a separator, make sure it does.
        return false if code[-1] != SEPARATOR
      end

      # If there are characters after the separator, make sure there isn't just
      # one of them (not legal).
      return false if code.length - separator_index - 1 == 1

      # Check code contains only valid characters.
      code.chars.each do |ch|
        return false if ch.ord >= DECODE.length || DECODE[ch.ord] < -1
      end
      true
    end

    # Checks if the given plus+codes is in short format.
    #
    # @param code [String] a plus+codes
    # @return [TrueClass, FalseClass] true if the code is short, false otherwise
    def short?(code)
      return false unless valid?(code)
      # If there are less characters than expected before the SEPARATOR.
      code.index(SEPARATOR) >= 0 && code.index(SEPARATOR) < SEPARATOR_POSITION
    end

    # Checks if the given plus+codes is in full format.
    #
    # @param code [String] a plus+codes
    # @return [TrueClass, FalseClass] true if the code is full, false otherwise
    def full?(code)
      return false unless valid?(code)
      #  If it's short, it's not full.
      return false if short?(code)

      # Work out what the first latitude character indicates for latitude.
      first_lat_value = DECODE[code[0].ord] * ENCODING_BASE
      # The code would decode to a latitude of >= 90 degrees.
      return false if first_lat_value >= LATITUDE_MAX * 2
      if code.length > 1
        # Work out what the first longitude character indicates for longitude.
        first_lng_value = DECODE[code[1].ord] * ENCODING_BASE
        # The code would decode to a longitude of >= 180 degrees.
        return false if first_lng_value >= LONGITUDE_MAX * 2
      end
      true
    end

    # Encodes given latitude and longitude with the optionally provided code length.
    #
    # @param latitude [Numeric] a latitude in degrees
    # @param longitude [Numeric] a longitude in degrees
    # @param code_length [Integer] the number of characters in the code, this excludes the separator
    # @return [String] a plus+codes
    def encode(latitude, longitude, code_length = PAIR_CODE_LENGTH)
      if code_length < 2 || (code_length < SEPARATOR_POSITION && code_length.odd?)
        raise ArgumentError, "Invalid Open Location Code length: #{code_length}"
      end

      latitude = clip_latitude(latitude)
      longitude = normalize_longitude(longitude)
      if latitude == 90
        latitude = latitude - compute_latitude_precision(code_length).to_f
      end
      code = encode_pairs(latitude, longitude, [code_length, PAIR_CODE_LENGTH].min)
      # If the requested length indicates we want grid refined codes.
      if code_length > PAIR_CODE_LENGTH
        code += encode_grid(latitude, longitude, code_length - PAIR_CODE_LENGTH)
      end
      code
    end

    # Decodes the given plus+codes in to a [CodeArea].
    #
    # @param code [String] a plus+codes
    # @return [CodeArea] a code area which contains the coordinates
    def decode(code)
      raise ArgumentError,
        "Passed Open Location Code is not a valid full code: #{code}" unless full?(code)

      # Strip out separator character (we've already established the code is
      # valid so the maximum is one), padding characters and convert to upper
      # case.
      code = code.gsub(SEPARATOR, '')
      code = code.gsub(/#{PADDING}+/, '')
      code = code.upcase
      # Decode the lat/lng pair component.
      code_area = decode_pairs(code[0...[code.length, PAIR_CODE_LENGTH].min])
      # If there is a grid refinement component, decode that.
      return code_area if code.length <= PAIR_CODE_LENGTH

      grid_area = decode_grid(code[PAIR_CODE_LENGTH..-1])
      CodeArea.new(code_area.latitude_lo + grid_area.latitude_lo,
        code_area.longitude_lo + grid_area.longitude_lo,
        code_area.latitude_lo + grid_area.latitude_hi,
        code_area.longitude_lo + grid_area.longitude_hi,
        code_area.code_length + grid_area.code_length)
    end

    # Finds the full plus+codes from given short plus+codes, reference latitude and longitude.
    #
    # @param code [String] a plus+codes
    # @param reference_latitude [Numeric] a reference latitude in degrees
    # @param reference_longitude [Numeric] a reference longitude in degrees
    # @return [String] a plus+codes
    def recover_nearest(short_code, reference_latitude, reference_longitude)
      unless short?(short_code)
        if full?(short_code)
          return short_code
        else
          raise ArgumentError, "ValueError: Passed short code is not valid: #{short_code}"
        end
      end

      # Ensure that latitude and longitude are valid.
      reference_latitude = clip_latitude(reference_latitude)
      reference_longitude = normalize_longitude(reference_longitude)

      # Clean up the passed code.
      short_code = short_code.upcase
      # Compute the number of digits we need to recover.
      padding_length = SEPARATOR_POSITION - short_code.index(SEPARATOR)
      # The resolution (height and width) of the padded area in degrees.
      resolution = 20 ** (2 - (padding_length / 2))
      # Distance from the center to an edge (in degrees).
      area_to_edge = resolution / 2.0

      # Now round down the reference latitude and longitude to the resolution.
      rounded_latitude = (reference_latitude / resolution).floor * resolution
      rounded_longitude = (reference_longitude / resolution).floor * resolution

      # Use the reference location to pad the supplied short code and decode it.
      code_area = decode(
        encode(rounded_latitude, rounded_longitude).slice(0, padding_length) +
          short_code)
      # How many degrees latitude is the code from the reference? If it is more
      # than half the resolution, we need to move it east or west.
      degrees_difference = code_area.latitude_center - reference_latitude
      if degrees_difference > area_to_edge
        # If the center of the short code is more than half a cell east,
        # then the best match will be one position west.
        code_area.latitude_center -= resolution
      elsif degrees_difference < -area_to_edge
        # If the center of the short code is more than half a cell west,
        # then the best match will be one position east.
        code_area.latitude_center += resolution
      end

      # How many degrees longitude is the code from the reference?
      degrees_difference = code_area.longitude_center - reference_longitude
      if degrees_difference > area_to_edge
        code_area.longitude_center -= resolution
      elsif degrees_difference < -area_to_edge
        code_area.longitude_center += resolution
      end
      encode(code_area.latitude_center, code_area.longitude_center, code_area.code_length)
    end

    # Shortens the given full plus+codes by provided reference latitude and longitude.
    #
    # @param code [String] a plus+codes
    # @param latitude [Numeric] a latitude in degrees
    # @param longitude [Numeric] a longitude in degrees
    # @return [String] a short plus+codes
    def shorten(code, latitude, longitude)
      raise ArgumentError,
        "ValueError: Passed code is not valid and full: #{code}" unless full?(code)
      raise ArgumentError,
        "ValueError: Cannot shorten padded codes: #{code}" unless code.index(PADDING).nil?

      code = code.upcase
      code_area = decode(code)
      if code_area.code_length < MIN_TRIMMABLE_CODE_LEN
        raise RangeError,
          "ValueError: Code length must be at least #{MIN_TRIMMABLE_CODE_LEN}"
      end
      # Ensure that latitude and longitude are valid.
      latitude = clip_latitude(latitude)
      longitude = normalize_longitude(longitude)
      # How close are the latitude and longitude to the code center.
      range = [(code_area.latitude_center - latitude).abs,
        (code_area.longitude_center - longitude).abs].max
      i = PAIR_RESOLUTIONS.length - 2
      while i >= 1 do
        # Check if we're close enough to shorten. The range must be less than 1/2
        # the resolution to shorten at all, and we want to allow some safety, so
        # use 0.3 instead of 0.5 as a multiplier.
        return code[(i + 1) * 2..-1] if range < (PAIR_RESOLUTIONS[i] * 0.3)
        # Trim it.
        i -= 1
      end
      code
    end

    private

    def encode_pairs(latitude, longitude, code_length)
      code = ''
      # Adjust latitude and longitude so they fall into positive ranges.
      adjusted_latitude = latitude + LATITUDE_MAX
      adjusted_longitude = longitude + LONGITUDE_MAX
      # Count digits - can't use string length because it may include a separator
      # character.
      digit_count = 0
      while (digit_count < code_length) do
        # Provides the value of digits in this place in decimal degrees.
        place_value = PAIR_RESOLUTIONS[(digit_count / 2).to_i]
        # Do the latitude - gets the digit for this place and subtracts that for
        # the next digit.
        digit_value = (adjusted_latitude / place_value).to_i
        adjusted_latitude -= digit_value * place_value
        code += CODE_ALPHABET[digit_value]
        digit_count += 1
        # And do the longitude - gets the digit for this place and subtracts that
        # for the next digit.
        digit_value = (adjusted_longitude / place_value).to_i
        adjusted_longitude -= digit_value * place_value
        code += CODE_ALPHABET[digit_value]
        digit_count +=1
        # Should we add a separator here?
        code += SEPARATOR if digit_count == SEPARATOR_POSITION && digit_count < code_length
      end
      # If necessary, Add padding.
      if code.length < SEPARATOR_POSITION
        code = code + (PADDING * (SEPARATOR_POSITION - code.length))
      end
      code = code + SEPARATOR if code.length == SEPARATOR_POSITION
      code
    end

    def encode_grid(latitude, longitude, code_length)
      code = ''
      lat_place_value = GRID_SIZE_DEGREES
      lng_place_value = GRID_SIZE_DEGREES
      # Adjust latitude and longitude so they fall into positive ranges and
      # get the offset for the required places.
      adjusted_latitude = (latitude + LATITUDE_MAX) % lat_place_value
      adjusted_longitude = (longitude + LONGITUDE_MAX) % lng_place_value
      (1..code_length).each do
        # Work out the row and column.
        row = (adjusted_latitude / (lat_place_value / GRID_ROWS)).floor
        col = (adjusted_longitude / (lng_place_value / GRID_COLUMNS)).floor
        lat_place_value /= GRID_ROWS
        lng_place_value /= GRID_COLUMNS
        adjusted_latitude -= row * lat_place_value
        adjusted_longitude -= col * lng_place_value
        code += CODE_ALPHABET[row * GRID_COLUMNS + col]
      end
      code
    end

    def decode_pairs(code)
      # Get the latitude and longitude values. These will need correcting from
      # positive ranges.
      latitude = decode_pairs_sequence(code, 0.0)
      longitude = decode_pairs_sequence(code, 1.0)
      # Correct the values and set them into the CodeArea object.
      CodeArea.new(latitude[0] - LATITUDE_MAX,
        longitude[0] - LONGITUDE_MAX, latitude[1] - LATITUDE_MAX,
        longitude[1] - LONGITUDE_MAX, code.length)
    end

    def decode_pairs_sequence(code, offset)
      i = 0
      value = 0
      while i * 2 + offset < code.length do
        value += DECODE[code[i * 2 + offset.floor].ord] * PAIR_RESOLUTIONS[i]
        i += 1
      end
      [value, value + PAIR_RESOLUTIONS[i - 1]]
    end

    def decode_grid(code)
      latitude_lo = 0.0
      longitude_lo = 0.0
      lat_place_value = GRID_SIZE_DEGREES
      lng_place_value = GRID_SIZE_DEGREES
      (0...code.length).each do |i|
        code_index = DECODE[code[i].ord]
        row = (code_index / GRID_COLUMNS).floor()
        col = code_index % GRID_COLUMNS

        lat_place_value /= GRID_ROWS
        lng_place_value /= GRID_COLUMNS

        latitude_lo += row * lat_place_value
        longitude_lo += col * lng_place_value
      end
      CodeArea.new(latitude_lo, longitude_lo, latitude_lo + lat_place_value,
        longitude_lo + lng_place_value, code.length)
    end

    def clip_latitude(latitude)
      [90.0, [-90.0, latitude].max].min
    end

    def compute_latitude_precision(code_length)
      if code_length <= 10
        20 ** ((code_length / -2).to_i + 2)
      else
        (20 ** -3) / (GRID_ROWS ** (code_length - 10))
      end
    end

    def normalize_longitude(longitude)
      begin
        longitude += 360
      end while longitude < -180
      begin
        longitude -= 360
      end while longitude >= 180
      longitude
    end

  end

end
