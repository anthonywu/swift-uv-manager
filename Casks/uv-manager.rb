cask "uv-manager" do
  version "0.5.0"
  sha256 "7b735758fafa9eb4f16b8591eb9e75bea6f92aac711e2bd19d2fc4ff41f69638"

  url "https://github.com/anthonywu/swift-uv-manager/releases/download/v#{version}/UV.Manager-#{version}.dmg"
  name "UV Manager"
  desc "Native macOS interface for managing Python tools and runtimes with uv"
  homepage "https://github.com/anthonywu/swift-uv-manager"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "UV Manager.app"

  zap trash: [
    "~/Library/Caches/com.anthonywu.uvmanager",
    "~/Library/Preferences/com.anthonywu.uvmanager.plist",
    "~/Library/Saved Application State/com.anthonywu.uvmanager.savedState",
  ]
end
