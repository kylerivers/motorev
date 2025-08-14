import Foundation
import MapKit

final class CachedTileOverlay: MKTileOverlay {
    private let cacheDir: URL
    private let session: URLSession = .shared
    
    init(template: String) {
        self.cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("tiles")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        super.init(urlTemplate: template)
        canReplaceMapContent = false
    }
    
    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let url = url(forTilePath: path)
        let filename = "z\(path.z)_x\(path.x)_y\(path.y).png"
        let fileURL = cacheDir.appendingPathComponent(filename)
        if let data = try? Data(contentsOf: fileURL) {
            result(data, nil)
            return
        }
        session.dataTask(with: url) { data, _, error in
            if let data = data {
                try? data.write(to: fileURL)
                result(data, nil)
            } else {
                result(nil, error)
            }
        }.resume()
    }
} 