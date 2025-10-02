class Brewup < Formula
  desc "🍺 CLI tool to automate Homebrew package management"
  homepage "https://github.com/xcrong/brewup"
  url "https://github.com/xcrong/brewup/releases/download/v0.1.0/brewup-v0.1.0-x86_64-apple-darwin.tar.gz"
  sha256 "REPLACE_WITH_ACTUAL_SHA256"
  license "MIT"
  version "0.1.0"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/xcrong/brewup/releases/download/v0.1.0/brewup-v0.1.0-x86_64-apple-darwin.tar.gz"
      sha256 "REPLACE_WITH_ACTUAL_SHA256_FOR_INTEL"
    end

    if Hardware::CPU.arm?
      url "https://github.com/xcrong/brewup/releases/download/v0.1.0/brewup-v0.1.0-aarch64-apple-darwin.tar.gz"
      sha256 "REPLACE_WITH_ACTUAL_SHA256_FOR_ARM"
    end
  end

  def install
    bin.install "brewup"
  end

  test do
    system "#{bin}/brewup", "--version"
  end
end
