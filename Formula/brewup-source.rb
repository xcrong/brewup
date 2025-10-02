class Brewup < Formula
  desc "🍺 CLI tool to automate Homebrew package management"
  homepage "https://github.com/xcrong/brewup"
  url "https://github.com/xcrong/brewup/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "REPLACE_WITH_ACTUAL_SHA256"
  license "MIT"
  version "0.1.0"

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
  end

  test do
    system "#{bin}/brewup", "--version"
  end
end
