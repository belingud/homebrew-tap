class GhDownload < Formula
  desc "Download a file or directory from a GitHub repository path"
  homepage "https://github.com/belingud/gh-download"
  url "https://github.com/belingud/gh-download.git",
      tag:      "v0.5.0",
      revision: "6191f93c1fd92467d15ef808d69f29d5cc2fb6b3"
  version "0.5.0"
  license "MIT"
  head "https://github.com/belingud/gh-download.git", branch: "master"

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/gh-download --version")
  end
end
