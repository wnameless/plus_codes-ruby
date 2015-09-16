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
      return false if code.nil? || code.length < 2
      return false unless valid_separator?(code)
      return false unless valid_padding?(code)
      return false if code.split(SEPARATOR).last.length == 1
      return false if code.chars.detect { |ch| invlid_character?(ch) }
      true
    end

    def invlid_character?(ch)
      DECODE[ch.ord].nil? || DECODE[ch.ord] < -1
    end
    private :invlid_character?

    def valid_separator?(code)
      return false if code.count(SEPARATOR) != 1
      separator_index = code.index(SEPARATOR)
      return false if separator_index > SEPARATOR_POSITION
      separator_index.even?
    end
    private :valid_separator?

    def valid_padding?(code)
      return true unless code.include?(PADDING)
      return false if code.start_with?(PADDING)
      return false if code[-1] != SEPARATOR
      return false if code[-2] != PADDING
      pad_match = code.scan(/#{PADDING}+/)
      return false unless pad_match.one?
      padding = pad_match[0]
      return false if padding.length.odd?
      padding.length <= SEPARATOR_POSITION - 2
    end
    private :valid_padding?

    # Checks if the given plus+codes is in short format.
    #
    # @param code [String] a plus+codes
    # @return [TrueClass, FalseClass] true if the code is short, false otherwise
    def short?(code)
      valid?(code) && code.index(SEPARATOR) < SEPARATOR_POSITION
    end

    # Checks if the given plus+codes is in full format.
    #
    # @param code [String] a plus+codes
    # @return [TrueClass, FalseClass] true if the code is full, false otherwise
    def full?(code)
      valid?(code) && !short?(code)
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
      latitude -= compute_latitude_precision(code_length) if latitude == 90

      code = encode_pairs(latitude, longitude, [code_length, PAIR_CODE_LENGTH].min)
      if code_length > PAIR_CODE_LENGTH
        code += encode_grid(latitude, longitude, code_length - PAIR_CODE_LENGTH)
      else
        code
      end
    end

    # Decodes the given plus+codes in to a [CodeArea].
    #
    # @param code [String] a plus+codes
    # @return [CodeArea] a code area which contains the coordinates
    def decode(code)
      raise ArgumentError,
        "Passed Open Location Code is not a valid full code: #{code}" unless full?(code)

      code = code.gsub(SEPARATOR, '')
      code = code.gsub(/#{PADDING}+/, '')
      code = code.upcase
      code_area = decode_pairs(code[0...[code.length, PAIR_CODE_LENGTH].min])

      if code.length <= PAIR_CODE_LENGTH
        code_area
      else
        grid_area = decode_grid(code[PAIR_CODE_LENGTH..-1])
        CodeArea.new(code_area.latitude_lo + grid_area.latitude_lo,
          code_area.longitude_lo + grid_area.longitude_lo,
          code_area.latitude_lo + grid_area.latitude_hi,
          code_area.longitude_lo + grid_area.longitude_hi,
          code_area.code_length + grid_area.code_length)
      end
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

      reference_latitude = clip_latitude(reference_latitude)
      reference_longitude = normalize_longitude(reference_longitude)
      short_code = short_code.upcase

      filling_length = SEPARATOR_POSITION - short_code.index(SEPARATOR)
      resolution = ENCODING_BASE ** (2 - (filling_length / 2))
      area_to_edge = resolution / 2.0

      rounded_latitude = (reference_latitude / resolution).floor * resolution
      rounded_longitude = (reference_longitude / resolution).floor * resolution
      prefix_code = encode(rounded_latitude, rounded_longitude).slice(0, filling_length)

      code_area = decode(prefix_code + short_code)
      lat_diff = code_area.latitude_center - reference_latitude
      if lat_diff > area_to_edge
        code_area.latitude_center -= resolution
      elsif lat_diff < -area_to_edge
        code_area.latitude_center += resolution
      end

      lng_diff = code_area.longitude_center - reference_longitude
      if lng_diff > area_to_edge
        code_area.longitude_center -= resolution
      elsif lng_diff < -area_to_edge
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

      latitude = clip_latitude(latitude)
      longitude = normalize_longitude(longitude)
      range = upper_range(code_area, latitude, longitude)
      PAIR_RESOLUTIONS[1..-2].reverse.each_with_index do |pair_res, idx|
        return code[(SEPARATOR_POSITION - idx * 2)..-1] if range < pair_res * 0.3
      end
      code
    end

    private

    def upper_range(code_area, latitude, longitude)
      lat_range = (code_area.latitude_center - latitude).abs
      lng_range = (code_area.longitude_center - longitude).abs
      [lat_range, lng_range].max
    end

    def encode_pairs(latitude, longitude, code_length)
      code = ''
      adjusted_latitude = latitude + LATITUDE_MAX
      adjusted_longitude = longitude + LONGITUDE_MAX

      digit_count = 0
      while (digit_count < code_length) do
        res_value = PAIR_RESOLUTIONS[(digit_count / 2).to_i]

        digit_value = (adjusted_latitude / res_value).to_i
        adjusted_latitude -= digit_value * res_value
        code += CODE_ALPHABET[digit_value]
        digit_count += 1

        digit_value = (adjusted_longitude / res_value).to_i
        adjusted_longitude -= digit_value * res_value
        code += CODE_ALPHABET[digit_value]
        digit_count +=1

        code += SEPARATOR if digit_count == SEPARATOR_POSITION && digit_count < code_length
      end

      padded_code(code)
    end

    def padded_code(code)
      if code.length < SEPARATOR_POSITION
        code += (PADDING * (SEPARATOR_POSITION - code.length))
        code += SEPARATOR
      end
      code
    end

    def encode_grid(latitude, longitude, code_length)
      code = ''
      lat_place_value = GRID_SIZE_DEGREES
      lng_place_value = GRID_SIZE_DEGREES
      adjusted_latitude = (latitude + LATITUDE_MAX) % lat_place_value
      adjusted_longitude = (longitude + LONGITUDE_MAX) % lng_place_value

      (1..code_length).each do
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
      latitude = decode_pairs_sequence(code)
      longitude = decode_pairs_sequence(code, 1)
      CodeArea.new(latitude[0] - LATITUDE_MAX,
        longitude[0] - LONGITUDE_MAX, latitude[1] - LATITUDE_MAX,
        longitude[1] - LONGITUDE_MAX, code.length)
    end

    def decode_pairs_sequence(code, offset = 0)
      i = 0
      value = 0
      while i * 2 + offset < code.length do
        value += DECODE[code[i * 2 + offset].ord] * PAIR_RESOLUTIONS[i]
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
        row = (code_index / GRID_COLUMNS).floor
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
        ENCODING_BASE ** ((code_length / -2).to_i + 2)
      else
        (ENCODING_BASE ** -3) / (GRID_ROWS ** (code_length - 10))
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
