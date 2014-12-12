module Flintlock
  class InvalidModule < RuntimeError; end
  class UnsupportedModuleURI < RuntimeError; end
  class ModuleDownloadError < RuntimeError; end
  class RunFailure < RuntimeError; end
  class PackagingError < RuntimeError; end
end
