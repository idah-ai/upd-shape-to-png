# frozen_string_literal: true

RSpec.describe PngWriter do
  subject(:writer) { described_class.new }
  let(:output_dir) { test_output_dir }

  describe "#write" do
    let(:width) { 4 }
    let(:height) { 4 }

    it "writes a valid PNG file" do
      # 4x4 checkerboard: first two bg, next two fg, etc.
      image_data = "\x00\x00\x01\x01\x00\x00\x01\x01\x00\x00\x01\x01\x00\x00\x01\x01"
      path = File.join(output_dir, "test_mask.png")

      writer.write(image_data, width, height, path)
      expect(File).to exist(path)

      # Verify it's a valid PNG
      png_header = File.binread(path, 8)
      expect(png_header).to eq([137, 80, 78, 71, 13, 10, 26, 10].pack("C*"))
    end

    it "creates a valid PNG file with pixel data" do
      image_data = "\x01" * (width * height) # all foreground
      path = File.join(output_dir, "all_white.png")

      writer.write(image_data, width, height, path)
      expect(File).to exist(path)

      # Verify valid PNG
      png_header = File.binread(path, 8)
      expect(png_header).to eq([137, 80, 78, 71, 13, 10, 26, 10].pack("C*"))

      # Read back and verify pixel dimensions
      if HAVE_CHUNKY_PNG
        png = ChunkyPNG::Image.from_file(path)
        expect(png.width).to eq(width)
        expect(png.height).to eq(height)
      end
    end

    it "writes an all-black image for empty mask" do
      image_data = "\x00" * (width * height)
      path = File.join(output_dir, "all_black.png")

      writer.write(image_data, width, height, path)
      expect(File).to exist(path)
      expect(File.size(path)).to be > 0
    end
  end

  describe "#write_combined" do
    let(:width) { 3 }
    let(:height) { 2 }

    it "writes a valid combined RGB PNG" do
      # 3x2 image: [bg, cat1, cat2, bg, cat1, cat2]
      combined = "\x00\x01\x02\x00\x01\x02"
      path = File.join(output_dir, "test_combined.png")

      writer.write_combined(combined, width, height, path)
      expect(File).to exist(path)

      png_header = File.binread(path, 8)
      expect(png_header).to eq([137, 80, 78, 71, 13, 10, 26, 10].pack("C*"))
    end

    it "maps category index to distinct colors" do
      # Single pixel, category 1 (red)
      combined = "\x01"
      path = File.join(output_dir, "cat1.png")
      writer.write_combined(combined, 1, 1, path)
      expect(File).to exist(path)
      expect(File.size(path)).to be > 0
    end

    it "handles empty (all background) combined image" do
      combined = "\x00" * 9 # 3x3
      path = File.join(output_dir, "all_bg_combined.png")
      writer.write_combined(combined, 3, 3, path)
      expect(File).to exist(path)
    end
  end

  describe ".category_color" do
    it "returns black for index 0" do
      color = described_class.new.send(:category_color, 0)
      expect(color).to eq([0, 0, 0])
    end

    it "returns red for index 1" do
      color = described_class.new.send(:category_color, 1)
      expect(color).to eq([255, 0, 0])
    end

    it "cycles through the palette for large indices" do
      color = described_class.new.send(:category_color, 16)
      # 16 % 16 = 0, should be black
      expect(color).to eq([0, 0, 0])
    end
  end
end
