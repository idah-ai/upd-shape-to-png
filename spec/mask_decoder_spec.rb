# frozen_string_literal: true

RSpec.describe MaskDecoder do
  subject(:decoder) { described_class.new }

  describe "#decode" do
    context "with empty or nil input" do
      it "returns a zero-filled buffer when shape is nil" do
        result = decoder.decode(nil, 10, 10)
        expect(result.bytesize).to eq(100)
        expect(result.bytes).to all(eq(0))
      end

      it "returns a zero-filled buffer when shape is empty hash" do
        result = decoder.decode({}, 10, 10)
        expect(result.bytesize).to eq(100)
        expect(result.bytes).to all(eq(0))
      end
    end

    context "with single-tile shape" do
      # A single 128x128 tile covering the full image
      let(:shape) do
        # All-foreground tile: runs [0, 16384]
        # bytes: [0x00, 0xC0, 0x00] → 0 = bg, then 2-byte 16384
        rle = [0x00, 0xC0, 0x00].pack("C*")
        encoded = [rle].pack("m0")
        { "tile-0x0" => { "rle" => encoded } }
      end

      it "decodes a single tile into the full image" do
        result = decoder.decode(shape, 128, 128)
        expect(result.bytesize).to eq(128 * 128)
        expect(result.bytes).to all(eq(1))
      end

      it "handles images smaller than tile size" do
        # 64x64 image, single tile at (0,0), tile data has the first 64x64 pixels set
        # Make a tile with only the first 64 rows of 128 set
        # Runs: first 64 rows of 128 = 8192 bg pixels, then nothing... actually let's just use partial.
        # Easiest: make the tile all-bg, then verify only the sliced area is 0
        bg_tile = [0xC0, 0x00].pack("C*") # 16384 bg pixels
        encoded = [bg_tile].pack("m0")

        result = decoder.decode({ "tile-0x0" => { "rle" => encoded } }, 64, 64)
        expect(result.bytesize).to eq(4096)
        expect(result.bytes).to all(eq(0))
      end
    end

    context "with multi-tile shape" do
      it "assembles tiles into a grid" do
        # 256x128 image = 2 tiles wide, 1 tile tall
        # tile-0x0 has pixel (0,0) set only → first pixel of first tile is foreground
        # tile-1x0 has pixel (0,0) set only → first pixel of second tile is foreground

        # Create an RLE for a single foreground pixel at position 0:
        # Runs: [0, 1, 16383] → bg=0, fg=1, bg=16383  (total = 16384)
        # Actually simpler: runs [1] → bg=1, implicit=16383, bit=1 → fill fg for implicit
        # That would be mostly fg. Let's do: first pixel only = runs [0, 1, 16383]
        # bytes: [0x00, 0x01, 0xC0, 0x7F] -- 16383 = 0x3FFF → b0=0x80|0x3F=0xBF, b1=0xFF
        # Wait: 16383 in hex = 0x3FFF
        # (0x3FFF >> 8) = 0x3F, (0x3FFF & 0xFF) = 0xFF
        # b0 = 0x80 | 0x3F = 0xBF, b1 = 0xFF
        runs_bytes = [0x00, 0x01, 0xBF, 0xFF].pack("C*")
        rle = [runs_bytes].pack("m0")

        shape = {
          "tile-0x0" => { "rle" => rle },
          "tile-1x0" => { "rle" => rle }
        }

        result = decoder.decode(shape, 256, 128)
        expect(result.bytesize).to eq(256 * 128)

        bytes = result.bytes

        # First pixel of the image (tile-0x0, pixel 0) should be 1
        expect(bytes[0]).to eq(1)

        # First pixel of the second tile (x=128, y=0) should be 1
        expect(bytes[128]).to eq(1)

        # Second pixel of the first tile (x=1, y=0) should be 0
        expect(bytes[1]).to eq(0)
      end
    end

    context "with shape data passed as string (legacy format)" do
      it "handles tile data where value is a string instead of hash" do
        rle = [0x00, 0xC0, 0x00].pack("C*")
        encoded = [rle].pack("m0")
        shape = { "tile-0x0" => encoded } # string, not hash

        result = decoder.decode(shape, 128, 128)
        expect(result.bytesize).to eq(128 * 128)
        expect(result.bytes).to all(eq(1))
      end
    end
  end
end