# Plus+Codes is a Ruby implementation of Google Open Location Code(Plus+Codes).
# @author We-Ming Wu
module PlusCodes

  # A separator used to break the code into two parts to aid memorability.
  SEPARATOR = '+'.freeze

  # The number of characters to place before the separator.
  SEPARATOR_POSITION = 8

  # The character used to pad codes.
  PADDING = '0'.freeze

  # The character set used to encode the values.
  CODE_ALPHABET = '23456789CFGHJMPQRVWX'.freeze

  # The base to use to convert numbers to/from.
  ENCODING_BASE = CODE_ALPHABET.length

  # The maximum value for latitude in degrees.
  LATITUDE_MAX = 90

  # The maximum value for longitude in degrees.
  LONGITUDE_MAX = 180

  # Maximum code length using lat/lng pair encoding. The area of such a
  # code is approximately 13x13 meters (at the equator), and should be suitable
  # for identifying buildings. This excludes prefix and separator characters.
  PAIR_CODE_LENGTH = 10

  # The resolution values in degrees for each position in the lat/lng pair
  # encoding. These give the place value of each position, and therefore the
  # dimensions of the resulting area.
  PAIR_RESOLUTIONS = [20.0, 1.0, 0.05, 0.0025, 0.000125].freeze

  # Number of columns in the grid refinement method.
  GRID_COLUMNS = 4

  #  Number of rows in the grid refinement method.
  GRID_ROWS = 5

  # Size of the initial grid in degrees.
  GRID_SIZE_DEGREES = 0.000125

  # Minimum length of a code that can be shortened.
  MIN_TRIMMABLE_CODE_LEN = 6

  # Decoder lookup table.
  # -2: illegal.
  # -1: Padding or Separator
  # >= 0: index in the alphabet.
  DECODE = [
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
    -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -1, -2, -2, -2, -2,
    -1, -2,  0,  1,  2,  3,  4,  5,  6,  7, -2, -2, -2, -2, -2, -2,
    -2, -2, -2,  8, -2, -2,  9, 10, 11, -2, 12, -2, -2, 13, -2, -2,
    14, 15, 16, -2, -2, -2, 17, 18, 19, -2, -2, -2, -2, -2, -2, -2,
    -2, -2, -2,  8, -2, -2,  9, 10, 11, -2, 12, -2, -2, 13, -2, -2,
    14, 15, 16, -2, -2, -2, 17, 18, 19, -2, -2, -2, -2, -2, -2, -2,].freeze

end
