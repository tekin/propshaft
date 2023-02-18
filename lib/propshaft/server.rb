require "rack/utils"

class Propshaft::Server
  def initialize(assembly, no_cache: false)
    @assembly = assembly
    @no_cache = no_cache
  end

  def call(env)
    path, digest = extract_path_and_digest(env)

    if (asset = @assembly.load_path.find(path)) && asset.fresh?(digest)
      compiled_content = @assembly.compilers.compile(asset)

      [
        200,
        {
          "content-length"  => compiled_content.length.to_s,
          "content-type"    => asset.content_type.to_s,
          "accept-encoding" => "vary",
          "etag"            => @no_cache ? nil : asset.digest,
          "cache-control"   => @no_cache ? "no-cache, no-store, must-revalidate" : "public, max-age=31536000, immutable",
          "vary"            => @no_cache ? "*" : nil
        }.compact,
        [ compiled_content ]
      ]
    else
      [ 404, { "content-type" => "text/plain", "content-length" => "9" }, [ "Not found" ] ]
    end
  end

  def inspect
    self.class.inspect
  end

  private
    def extract_path_and_digest(env)
      full_path = Rack::Utils.unescape(env["PATH_INFO"].to_s.sub(/^\//, ""))
      digest    = full_path[/-([0-9a-zA-Z]{7,128}(?:\.digested)?)\.[^.]+\z/, 1]
      path      = digest ? full_path.sub("-#{digest}", "") : full_path

      [ path, digest ]
    end
end
