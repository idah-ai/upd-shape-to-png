# frozen_string_literal: true

RSpec.describe UpdCli do
  subject(:cli) { described_class.new(updcli_path) }
  let(:updcli_path) { "/usr/bin/updcli" }
  let(:upd_file) { "/tmp/test.upd" }

  before do
    # Ensure the updcli binary "exists" for the test
    allow(File).to receive(:file?).with(updcli_path).and_return(true)
  end

  describe "#list_entry_ids" do
    context "with JSON output format" do
      let(:json_lines) do
        <<~OUTPUT
          2026-01-15 10:00:00 INFO - entry.list: {"id":"entry-1","name":"Image 1"}
          2026-01-15 10:00:01 INFO - entry.list: {"id":"entry-2","name":"Image 2"}
        OUTPUT
      end

      it "returns an array of entry IDs from log-prefixed JSON" do
        expect(cli).to receive(:run_cmd)
          .with(%r{/usr/bin/updcli.*entry list})
          .and_return(json_lines)

        ids = cli.list_entry_ids(upd_file)
        expect(ids).to eq(["entry-1", "entry-2"])
      end
    end

    context "when no entries found" do
      let(:no_entries) { "2026-01-15 INFO - entry.list: No entries found" }

      it "returns an empty array" do
        expect(cli).to receive(:run_cmd).and_return(no_entries)
        ids = cli.list_entry_ids(upd_file)
        expect(ids).to eq([])
      end
    end
  end

  describe "#list_annotation_ids" do
    it "returns annotation IDs" do
      output = <<~OUTPUT
        2026-01-15 INFO - annotation.list: {"id":"ann-1","shape_type":"idah-image:mask"}
        2026-01-15 INFO - annotation.list: {"id":"ann-2","shape_type":"idah-image:bounding-box"}
      OUTPUT

      expect(cli).to receive(:run_cmd).and_return(output)
      ids = cli.list_annotation_ids(upd_file)
      expect(ids).to eq(["ann-1", "ann-2"])
    end

    it "returns empty array for 'No annotation found'" do
      expect(cli).to receive(:run_cmd).and_return("2026-01-15 INFO - annotation.list: No annotation found")
      ids = cli.list_annotation_ids(upd_file)
      expect(ids).to eq([])
    end
  end

  describe "#show_entry" do
    it "returns parsed entry JSON" do
      output = <<~OUTPUT
        2026-01-15 INFO - entry.show: {"id":"entry-1","metadata":{"Name":"Test Image","Width":"640","Height":"480"}}
      OUTPUT

      expect(cli).to receive(:run_cmd).and_return(output)
      data = cli.show_entry(upd_file, "entry-1")
      expect(data).to be_a(Hash)
      expect(data["id"]).to eq("entry-1")
      expect(data["metadata"]["Name"]).to eq("Test Image")
      expect(data["metadata"]["Width"]).to eq("640")
    end
  end

  describe "#show_annotation" do
    it "returns parsed annotation JSON" do
      output = <<~OUTPUT
        2026-01-15 INFO - annotation.show: {"id":"ann-1","entry_id":"entry-1","shape_type":"idah-image:mask","category":"tumor","shape_args":{"tile-0x0":{"rle":"BQM="}}}
      OUTPUT

      expect(cli).to receive(:run_cmd).and_return(output)
      data = cli.show_annotation(upd_file, "ann-1")
      expect(data).to be_a(Hash)
      expect(data["id"]).to eq("ann-1")
      expect(data["shape_type"]).to eq("idah-image:mask")
      expect(data["category"]).to eq("tumor")
    end
  end

  describe "#list_annotations_full" do
    it "returns array of annotation hashes" do
      output = <<~OUTPUT
        2026-01-15 INFO - annotation.list: {"id":"ann-1","entry_id":"entry-1","shape_type":"idah-image:mask","category":"tumor","shape_args":{"tile-0x0":{"rle":"BQM="}}}
        2026-01-15 INFO - annotation.list: {"id":"ann-2","entry_id":"entry-1","shape_type":"idah-image:bounding-box","category":"tumor","shape_args":{"points":[[0.1,0.1],[0.9,0.1],[0.9,0.9],[0.1,0.9]]}}
      OUTPUT

      expect(cli).to receive(:run_cmd).and_return(output)
      annotations = cli.list_annotations_full(upd_file)
      expect(annotations.length).to eq(2)
      expect(annotations[0]["id"]).to eq("ann-1")
      expect(annotations[1]["shape_type"]).to eq("idah-image:bounding-box")
    end
  end

  describe "#initialize" do
    context "when updcli is not found" do
      it "raises an error" do
        # Stub File.file? to always return false for the binary search
        allow(File).to receive(:file?).and_return(false)
        # Stub backtick method (used for `which`) via Kernel to return empty
        allow(Kernel).to receive(:`).with(/which/).and_return("")

        expect { described_class.new("nonexistent-updcli") }
          .to raise_error(RuntimeError, /updcli not found/)
      end
    end
  end

  # Test private helper methods via .send for thorough coverage
  describe "private helpers" do
    describe "#parse_json_from_log" do
      it "extracts JSON from log-prefixed output" do
        result = cli.send(:parse_json_from_log, '2026-01-15 INFO - entry.show: {"id":"test"}')
        expect(result).to eq("id" => "test")
      end

      it "returns nil for empty output" do
        expect(cli.send(:parse_json_from_log, "")).to be_nil
      end

      it "returns nil for plain text without JSON" do
        result = cli.send(:parse_json_from_log, "Some random text")
        expect(result).to be_nil
      end
    end

    describe "#parse_id_list" do
      it "parses plain UUID lines" do
        output = "abc-123\ndef-456\n"
        ids = cli.send(:parse_id_list, output, json: false)
        expect(ids).to eq(["abc-123", "def-456"])
      end

      it "skips non-UUID lines in plain mode" do
        output = "abc-123\nSome error\n"
        ids = cli.send(:parse_id_list, output, json: false)
        expect(ids).to eq(["abc-123"])
      end
    end
  end
end