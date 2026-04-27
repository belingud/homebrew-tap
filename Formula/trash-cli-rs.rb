class TrashCliRs < Formula
  desc "Move files and directories to the system trash"
  homepage "https://github.com/belingud/trash-cli-rs"
  url "https://github.com/belingud/trash-cli-rs.git",
      tag:      "v1.0.0",
      revision: "578d4288f16c1999dcc2e83da892448ef7d183d4"
  version "1.0.0"
  license "MIT"
  head "https://github.com/belingud/trash-cli-rs.git", branch: "master"

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/trash --version")
  end
end
