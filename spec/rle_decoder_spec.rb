# frozen_string_literal: true

RSpec.describe RleDecoder do
  subject(:decoder) { described_class.new }

  describe "#decode_to_string" do
    context "with empty or nil input" do
      it "returns a zero-filled string when rle is nil" do
        result = decoder.decode_to_string(nil, 10, 10)
        expect(result.bytesize).to eq(100)
        expect(result.bytes).to all(eq(0))
      end

      it "returns a zero-filled string when rle is empty" do
        result = decoder.decode_to_string("", 10, 10)
        expect(result.bytesize).to eq(100)
        expect(result.bytes).to all(eq(0))
      end

      it "returns a zero-filled string when total pixels is zero" do
        result = decoder.decode_to_string("BQM=", 0, 100)
        expect(result.bytesize).to eq(0)
      end
    end

    context "with valid RLE data" do
      # The RLE encoding:
      #   - Base64 decode to raw bytes
      #   - If high bit (0x80) set, combine with next byte as 15-bit value
      #   - Otherwise, use byte directly as run length
      #   - Runs alternate: bg/fg starting with bit=0 (bg)

      it "decodes alternating runs correctly" do
        # Runs: [1, 1, 1, 1] → pattern: bg, fg, bg, fg
        # Bytes: [0x01, 0x01, 0x01, 0x01] → Base64 "AQEBAQ=="
        result = decoder.decode_to_string("AQEBAQ==", 1, 4)
        expect(result.bytesize).to eq(4)
        expect(result.bytes).to eq([0, 1, 0, 1])
      end

      it "decodes all-foreground" do
        # Runs: [0, 4] → bg=0, fg=4 → bytes [0x00, 0x04]
        result = decoder.decode_to_string("AAQ=", 1, 4)
        expect(result.bytesize).to eq(4)
        expect(result.bytes).to all(eq(1))
      end

      it "decodes all-background" do
        # Runs: [4] → bit=0 (bg) → all bg
        result = decoder.decode_to_string("BAA=", 1, 4)
        expect(result.bytesize).to eq(4)
        expect(result.bytes).to all(eq(0))
      end
    end

    context "with multi-byte run lengths" do
      it "handles runs > 127 bytes using 2-byte encoding" do
        # 150 pixels all fg: runs [0, 150]
        # 150 = 0x96 > 127 → 2-byte: b0=0x80|(150>>8)=0x80, b1=150&0xFF=0x96
        bytes = [0x00, 0x80, 0x96].pack("C*")
        rle = [bytes].pack("m0")
        result = decoder.decode_to_string(rle, 1, 150)
        expect(result.bytesize).to eq(150)
        expect(result.bytes).to all(eq(1))
      end
    end

    context "with implicit trailing run" do
      it "fills implicit pixels when the last run is foreground" do
        # Runs: [2] (bg=2) → implicit = 8, bit=1 → fill fg
        # Base64 of [0x02]: "Ag==" (single byte)
        result = decoder.decode_to_string("Ag==", 1, 10)
        expect(result.bytesize).to eq(10)
        expect(result.bytes[0..1]).to all(eq(0))
        expect(result.bytes[2..9]).to all(eq(1))
      end

      it "does NOT fill implicit pixels when last run is background" do
        # Runs: [4, 1] → bg=4, fg=1, total=5, implicit=5, bit=0 → bg
        result = decoder.decode_to_string("BAE=", 1, 10)
        expect(result.bytesize).to eq(10)
        expect(result.bytes[0..3]).to all(eq(0))
        expect(result.bytes[4]).to eq(1)
        expect(result.bytes[5..9]).to all(eq(0))
      end
    end

    context "with errors" do
      it "raises when RLE data exceeds tile size" do
        rle = [0x64, 0x64].pack("C*").then { |b| [b].pack("m0") }
        expect { decoder.decode_to_string(rle, 10, 10) }
          .to raise_error(ArgumentError, /exceeds tile size/)
      end

      it "raises on truncated 2-byte run" do
        bytes = [0x80].pack("C*")
        rle = [bytes].pack("m0")
        expect { decoder.decode_to_string(rle, 10, 10) }
          .to raise_error(ArgumentError, /Truncated RLE data/)
      end
    end

    context "with 128x128 tile (realistic size)" do
      it "decodes all-background tile" do
        # 16384 pixels all bg: single run of 16384
        # 16384 = 0x4000 → 2-byte: b0=0x80|0x40=0xC0, b1=0x00
        bytes = [0xC0, 0x00].pack("C*")
        rle = [bytes].pack("m0")
        result = decoder.decode_to_string(rle, 128, 128)
        expect(result.bytesize).to eq(16_384)
        expect(result.bytes).to all(eq(0))
      end

      it "decodes a checkerboard pattern" do
        # 2x2 tile: runs [1, 1, 1, 1] → bg, fg, bg, fg
        result = decoder.decode_to_string("AQEBAQ==", 2, 2)
        expect(result.bytesize).to eq(4)
        expect(result.bytes).to eq([0, 1, 0, 1])
      end
    end
  end
end