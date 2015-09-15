require 'test_helper'
require 'plus_codes/open_location_code'

class PlusCodesTest < Test::Unit::TestCase

  def setup
    @test_data_folder_path = File.join(File.dirname(__FILE__), 'test_data')
    @olc = PlusCodes::OpenLocationCode.new
  end

  def test_validity
    read_csv_lines('validityTests.csv').each do |line|
      cols = line.split(',')
      code = cols[0]
      is_valid = cols[1] == 'true'
      is_short = cols[2] == 'true'
      is_full = cols[3] == 'true'
      is_valid_olc = @olc.valid?(code)
      is_short_olc = @olc.short?(code)
      is_full_olc = @olc.full?(code)
      result = is_full == is_full_olc && is_short_olc == is_short && is_valid_olc == is_valid
      assert_true(result)
    end
  end

  def test_encode_decode
    read_csv_lines('encodingTests.csv').each do |line|
      cols = line.split(',')
      code_area = @olc.decode(cols[0])
      code = @olc.encode(cols[1].to_f, cols[2].to_f, code_area.code_length)
      assert_equal(cols[0], code)
      assert_true((code_area.latitude_lo - cols[3].to_f).abs < 0.001)
      assert_true((code_area.longitude_lo - cols[4].to_f).abs < 0.001)
      assert_true((code_area.latitude_hi - cols[5].to_f).abs < 0.001)
      assert_true((code_area.longitude_hi - cols[6].to_f).abs < 0.001)
    end
  end

  def test_shorten
    read_csv_lines('shortCodeTests.csv').each do |line|
      cols = line.split(',')
      code = cols[0]
      lat = cols[1].to_f
      lng = cols[2].to_f
      short_code = cols[3]
      short = @olc.shorten(code, lat, lng)
      assert_equal(short_code, short)
      expanded = @olc.recover_nearest(short, lat, lng)
      assert_equal(code, expanded)
    end
  end

  def test_longer_encoding_with_speacial_case
    assert_equal('CFX3X2X2+X2XXXXQ', @olc.encode(90.0, 1.0, 15));
  end

  def test_code_area_to_s
    read_csv_lines('encodingTests.csv').each do |line|
      cols = line.split(',')
      code_area = @olc.decode(cols[0])
      assert_equal("lat_lo: #{code_area.latitude_lo} long_lo: #{code_area.longitude_lo} " <<
          "lat_hi: #{code_area.latitude_hi} long_hi: #{code_area.longitude_hi} " <<
          "code_len: #{code_area.code_length}", code_area.to_s)
    end
  end

  def read_csv_lines(csv_file)
    f = File.open(File.join(@test_data_folder_path, csv_file), 'r')
    f.each_line.lazy.select { |line| line !~ /^\s*#/ }.map { |line| line.chop }
  end

end
