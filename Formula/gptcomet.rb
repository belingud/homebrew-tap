class Gptcomet < Formula
  desc "AI-powered Git commit message generator and reviewer"
  homepage "https://github.com/belingud/gptcomet"
  url "https://github.com/belingud/gptcomet.git",
      tag:      "v2.6.2",
      revision: "83048adcd013944f542d962bf7c96a9f36395d77"
  version "2.6.2"
  license "MIT"
  head "https://github.com/belingud/gptcomet.git", branch: "master"

  depends_on "go" => :build

  def install
    ENV["CGO_ENABLED"] = "0"

    ldflags = %W[
      -s -w
      -X main.version=#{version}
      -X github.com/belingud/gptcomet/cmd.InstallationSource=homebrew
    ]

    system "go", "build", *std_go_args(ldflags:), "."
    bin.install_symlink "gptcomet" => "gmsg"
  end

  def caveats
    <<~EOS
      GPTComet includes a built-in update command.
      If you installed it with Homebrew, use this instead of `gmsg update`:

        brew upgrade gptcomet
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/gptcomet --version")
    assert_match version.to_s, shell_output("#{bin}/gmsg --version")
  end
end
