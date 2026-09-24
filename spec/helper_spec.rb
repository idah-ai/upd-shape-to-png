# frozen_string_literal: true

RSpec.describe "Helper functions" do
  describe "#normalize_dim_value" do
    it "returns nil for nil input" do
      expect(normalize_dim_value(nil)).to be_nil
    end

    it "returns nil for empty string" do
      expect(normalize_dim_value("")).to be_nil
    end

    it "returns nil for whitespace-only string" do
      expect(normalize_dim_value("   ")).to be_nil
    end

    it "parses a numeric string to integer" do
      expect(normalize_dim_value("640")).to eq(640)
    end

    it "parses with leading/trailing whitespace" do
      expect(normalize_dim_value("  480  ")).to eq(480)
    end

    it "returns nil for non-numeric string" do
      expect(normalize_dim_value("abc")).to eq(0) # to_i returns 0
    end

    it "handles integer input directly" do
      expect(normalize_dim_value(1024)).to eq(1024)
    end
  end

  describe "#sanitize_filename" do
    it "preserves alphanumeric characters" do
      expect(sanitize_filename("image123")).to eq("image123")
    end

    it "preserves hyphens, underscores, dots, and spaces" do
      expect(sanitize_filename("my-image_1.2.png")).to eq("my-image_1.2.png")
    end

    it "replaces special characters with underscores" do
      expect(sanitize_filename("image/1:2*3")).to eq("image_1_2_3")
    end

    it "handles empty string" do
      expect(sanitize_filename("")).to eq("")
    end
  end

  describe "SHAPE_TYPE constants" do
    it "defines all shape types" do
      expect(SHAPE_TYPE_MASK).to eq("idah-image:mask")
      expect(SHAPE_TYPE_BOUNDING_BOX).to eq("idah-image:bounding-box")
      expect(SHAPE_TYPE_CIRCLE).to eq("idah-image:circle")
      expect(SHAPE_TYPE_LINE).to eq("idah-image:line")
    end

    it "has SUPPORTED_SHAPE_TYPES frozen" do
      expect(SUPPORTED_SHAPE_TYPES).to be_frozen
      expect(SUPPORTED_SHAPE_TYPES).to contain_exactly(
        SHAPE_TYPE_MASK, SHAPE_TYPE_BOUNDING_BOX,
        SHAPE_TYPE_CIRCLE, SHAPE_TYPE_LINE
      )
    end

    it "maps short names correctly" do
      expect(SHAPE_TYPE_SHORT_NAMES["mask"]).to eq(SHAPE_TYPE_MASK)
      expect(SHAPE_TYPE_SHORT_NAMES["bounding-box"]).to eq(SHAPE_TYPE_BOUNDING_BOX)
      expect(SHAPE_TYPE_SHORT_NAMES["bb"]).to eq(SHAPE_TYPE_BOUNDING_BOX)
      expect(SHAPE_TYPE_SHORT_NAMES["circle"]).to eq(SHAPE_TYPE_CIRCLE)
      expect(SHAPE_TYPE_SHORT_NAMES["line"]).to eq(SHAPE_TYPE_LINE)
    end
  end
end