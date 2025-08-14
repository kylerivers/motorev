import Foundation
import MapKit

final class TileCacheManager: NSObject {
    static let shared = TileCacheManager()
    private let cacheDir: URL
    private let session: URLSession
    
    private override init() {
        cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("tiles")
        session = URLSession(configuration: .default)
        super.init()
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
    
    func overlay(for template: String) -> MKTileOverlay {
        let overlay = MKTileOverlay(urlTemplate: template)
        overlay.canReplaceMapContent = false
        return overlay
    }
    
    func cacheTile(from url: URL, completion: (() -> Void)? = nil) {
        let path = cacheDir.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: path.path) { completion?(); return }
        let task = session.dataTask(with: url) { data, _, _ in
            if let data = data { try? data.write(to: path) }
            completion?()
        }
        task.resume()
    }
    
    // Prefetch tiles for a region across zoom levels
    func prefetch(region: MKCoordinateRegion, zoomRange: ClosedRange<Int>, template: String = "https://tile.openstreetmap.org/{z}/{x}/{y}.png", progress: @escaping (Double) -> Void, completion: @escaping () -> Void) {
        let minLat = region.center.latitude - region.span.latitudeDelta/2
        let maxLat = region.center.latitude + region.span.latitudeDelta/2
        let minLon = region.center.longitude - region.span.longitudeDelta/2
        let maxLon = region.center.longitude + region.span.longitudeDelta/2
        
        var urls: [URL] = []
        for z in zoomRange {
            let n = pow(2.0, Double(z))
            let xMin = Int(floor((minLon + 180.0) / 360.0 * n))
            let xMax = Int(floor((maxLon + 180.0) / 360.0 * n))
            let yMin = TileCacheManager.lat2tileY(maxLat, z: z)
            let yMax = TileCacheManager.lat2tileY(minLat, z: z)
            for x in xMin...xMax {
                for y in yMin...yMax {
                    if let url = URL(string: template.replacingOccurrences(of: "{z}", with: String(z)).replacingOccurrences(of: "{x}", with: String(x)).replacingOccurrences(of: "{y}", with: String(y))) {
                        urls.append(url)
                    }
                }
            }
        }
        if urls.isEmpty { completion(); return }
        
        let total = Double(urls.count)
        var completed = 0.0
        let group = DispatchGroup()
        for url in urls {
            group.enter()
            cacheTile(from: url) {
                completed += 1
                DispatchQueue.main.async { progress(completed/total) }
                group.leave()
            }
        }
        group.notify(queue: .main) { completion() }
    }
    
    func cacheSizeBytes() -> UInt64 {
        var total: UInt64 = 0
        if let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles) {
            for url in files {
                if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) {
                    total += UInt64(size)
                }
            }
        }
        return total
    }
    
    func clearCache() {
        if let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) {
            for url in files { try? FileManager.default.removeItem(at: url) }
        }
    }
    
    private static func lat2tileY(_ lat: Double, z: Int) -> Int {
        let latRad = lat * Double.pi / 180.0
        let n = pow(2.0, Double(z))
        let y = Int(floor((1.0 - log(tan(latRad) + 1.0/cos(latRad)) / Double.pi) / 2.0 * n))
        return max(0, min(Int(n)-1, y))
    }
} 