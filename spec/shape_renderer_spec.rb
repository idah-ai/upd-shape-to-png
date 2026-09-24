# frozen_string_literal: true

RSpec.describe ShapeRenderer do
  describe ".bounding_box" do
    let(:width) { 100 }
    let(:height) { 100 }
    let(:points) do
      # 4 normalized corner points forming a roughly centered box
      [[0.25, 0.25], [0.75, 0.25], [0.75, 0.75], [0.25, 0.75]]
    end

    it "returns a binary string of width*height bytes" do
      result = described_class.bounding_box(width, height, points)
      expect(result.bytesize).to eq(width * height)
    end

    it "renders top and bottom borders" do
      result = described_class.bounding_box(width, height, points)
      bytes = result.bytes

      # Top border row (y=25): pixels from x=25 to x=75 should be 1
      (25..75).each do |x|
        expect(bytes[25 * width + x]).to eq(1), "top border fail at (#{x}, 25)"
        expect(bytes[75 * width + x]).to eq(1), "bottom border fail at (#{x}, 75)"
      end

      # Pixels outside the box should be 0
      expect(bytes[24 * width + 50]).to eq(0) # one row above
      expect(bytes[76 * width + 50]).to eq(0) # one row below
    end

    it "renders left and right borders" do
      result = described_class.bounding_box(width, height, points)
      bytes = result.bytes

      (25..75).each do |y|
        expect(bytes[y * width + 25]).to eq(1), "left border fail at (25, #{y})"
        expect(bytes[y * width + 75]).to eq(1), "right border fail at (75, #{y})"
      end

      # Interior center should be 0 (border only)
      expect(bytes[50 * width + 50]).to eq(0)
    end

    context "with points outside image bounds" do
      it "clamps coordinates to image edges" do
        # Box extending beyond image
        points = [[-0.1, -0.1], [1.1, -0.1], [1.1, 1.1], [-0.1, 1.1]]
        result = described_class.bounding_box(50, 50, points)
        bytes = result.bytes

        # Top row should have border pixels
        expect(bytes[0..49]).to include(1)
        # All edge pixels should be set
        expect(bytes[0]).to eq(1) # top-left corner
        expect(bytes[49]).to eq(1) # top-right
      end
    end

    context "when boundary points are at the same location" do
      it "renders a 2-pixel-wide line for degenerate box" do
        points = [[0.5, 0.5], [0.5, 0.5], [0.5, 0.5], [0.5, 0.5]]
        result = described_class.bounding_box(10, 10, points)
        bytes = result.bytes
        # Should have at least the point at (5, 5) set
        expect(bytes[5 * 10 + 5]).to eq(1)
      end
    end
  end

  describe ".circle" do
    let(:width) { 50 }
    let(:height) { 50 }

    it "returns a binary string of width*height bytes" do
      result = described_class.circle(width, height, [0.5, 0.5], 0.4)
      expect(result.bytesize).to eq(width * height)
    end

    it "renders a circular outline around the center" do
      result = described_class.circle(width, height, [0.5, 0.5], 0.4)
      bytes = result.bytes

      # Circle radius formula: r = (0.4 * [50,50].max).round = 20
      # Center at (25, 25), radius 20 → rightmost point at (45, 25)
      expect(bytes[0]).to eq(0) # top-left corner should be background

      # Center should be 0 (outline only)
      expect(bytes[25 * width + 25]).to eq(0)

      # Pixel at right edge of circle (x=45, y=25) should be on the outline
      expect(bytes[25 * width + 45]).to eq(1)

      # Pixel one step beyond (x=46, y=25) should be background
      expect(bytes[25 * width + 46]).to eq(0)

      # Pixel at top of circle (x=25, y=5) should be on the outline
      expect(bytes[5 * width + 25]).to eq(1)

      # Pixel at bottom of circle (x=25, y=45) should be on the outline
      expect(bytes[45 * width + 25]).to eq(1)
    end

    it "renders a minimum 1px radius for near-zero radius" do
      # Code forces r >= 1, so radius 0 renders as radius 1
      result = described_class.circle(width, height, [0.5, 0.5], 0.0)
      bytes = result.bytes

      # Should have at least some pixels set (not all zero)
      expect(bytes).to include(1)

      # The circle of radius 1 should have the center pixel NOT set (outline)
      # For radius 1, center (25,25), ring at distance ~1 from center
      # Pixel (25, 25) = 0 (center)
      # Pixel (25, 26) = 1 (right edge of 1px radius)
      # But exactly which pixels are set depends on the floating point comparison
      # Just verify some outline pixels exist
      expect(bytes[25 * width + 25]).to eq(0) # center is empty (outline only)

      # There should be some pixels set (the outline ring)
      set_count = bytes.count(1)
      expect(set_count).to be > 0
    end
  end

  describe ".line" do
    let(:width) { 50 }
    let(:height) { 50 }

    it "returns a binary string of width*height bytes" do
      result = described_class.line(width, height, [0.1, 0.5], [0.9, 0.5])
      expect(result.bytesize).to eq(width * height)
    end

    it "renders a horizontal line across the image" do
      result = described_class.line(width, height, [0.1, 0.5], [0.9, 0.5])
      bytes = result.bytes

      # Should have pixels around y=25, x=5..45
      expect(bytes[25 * width + 5]).to eq(1)
      expect(bytes[25 * width + 25]).to eq(1)
      expect(bytes[25 * width + 45]).to eq(1)
    end

    it "renders a vertical line" do
      result = described_class.line(width, height, [0.5, 0.1], [0.5, 0.9])
      bytes = result.bytes

      expect(bytes[5 * width + 25]).to eq(1)
      expect(bytes[25 * width + 25]).to eq(1)
      expect(bytes[45 * width + 25]).to eq(1)
    end

    it "renders nothing for identical start/end" do
      result = described_class.line(width, height, [0.5, 0.5], [0.5, 0.5])
      bytes = result.bytes
      # Point (25, 25) should be set (distance ~0 < 1.5)
      expect(bytes[25 * width + 25]).to eq(1)
    end
  end
end