import SwiftUI
import MapKit

struct OfflineMapsView: View {
    @EnvironmentObject var locationManager: LocationManager
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
    )
    @State private var isDownloading = false
    @State private var downloadProgress = 0.0
    @State private var useOverlay = false
    @State private var prefetchProgress: Double = 0
    @State private var isPrefetching = false
    
    var body: some View {
        VStack(spacing: 16) {
            Toggle("Offline Mode", isOn: .init(get: { locationManager.isOfflineModeEnabled }, set: { _ in locationManager.toggleOfflineMode() }))
            Toggle("Use Tile Overlay", isOn: $useOverlay)
                .onChange(of: useOverlay) { _, newVal in
                    UserDefaults.standard.set(newVal, forKey: "useTileOverlay")
                    let key = overlayKey(for: region.center)
                    UserDefaults.standard.set(newVal, forKey: key)
                }
            if useOverlay {
                let template = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
                OverlayMapView(region: region, tileOverlay: CachedTileOverlay(template: template))
                    .frame(height: 240)
            } else {
                Map(position: .constant(.region(region))) {
                    UserAnnotation()
                }
                .frame(height: 240)
            }
            HStack {
                Button("Download Region") {
                    isDownloading = true
                    locationManager.downloadOfflineMap(for: region) { result in
                        isDownloading = false
                    }
                }
                .disabled(isDownloading)
                Button("Remove Region") {
                    locationManager.removeOfflineMap(for: region)
                }
                Button("Prefetch Tiles") {
                    isPrefetching = true
                    TileCacheManager.shared.prefetch(region: region, zoomRange: 8...14, progress: { p in
                        prefetchProgress = p
                    }, completion: {
                        isPrefetching = false
                    })
                }
            }
            if isDownloading {
                ProgressView(value: locationManager.offlineMapDownloadProgress)
            }
            if isPrefetching {
                ProgressView(value: prefetchProgress)
                Text(String(format: "Caching tiles %.0f%%", prefetchProgress*100)).font(.caption)
            }
            List {
                ForEach(Array(locationManager.offlineMapRegions.enumerated()), id: \.offset) { idx, reg in
                    Text(String(format: "Region %d (lat: %.2f, lon: %.2f)", idx+1, reg.center.latitude, reg.center.longitude))
                }
            }
            HStack {
                let sizeMB = Double(TileCacheManager.shared.cacheSizeBytes()) / (1024.0 * 1024.0)
                Text(String(format: "Cache: %.1f MB", sizeMB))
                Spacer()
                Button("Clear Cache") { TileCacheManager.shared.clearCache() }
            }
        }
        .padding()
        .navigationTitle("Offline Maps")
        .onAppear {
            useOverlay = UserDefaults.standard.bool(forKey: "useTileOverlay")
            if let loc = locationManager.location?.coordinate {
                region.center = loc
            } else {
                // fallback to a reasonable default (St. Petersburg, FL)
                region.center = CLLocationCoordinate2D(latitude: 27.7676, longitude: -82.6403)
            }
            let key = overlayKey(for: region.center)
            if UserDefaults.standard.object(forKey: key) != nil {
                useOverlay = UserDefaults.standard.bool(forKey: key)
            }
        }
        .onChange(of: locationManager.location) { _, newLoc in
            if let coord = newLoc?.coordinate {
                region.center = coord
            }
        }
    }
    
    private func overlayKey(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "overlay_%.3f_%.3f", coordinate.latitude, coordinate.longitude)
    }
}

private struct OverlayMapView: UIViewRepresentable {
    let region: MKCoordinateRegion
    let tileOverlay: MKTileOverlay
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.setRegion(region, animated: false)
        mapView.addOverlay(tileOverlay, level: .aboveLabels)
        mapView.delegate = context.coordinator
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.setRegion(region, animated: false)
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(tileOverlay: tileOverlay) }
    
    final class Coordinator: NSObject, MKMapViewDelegate {
        let tileOverlay: MKTileOverlay
        init(tileOverlay: MKTileOverlay) { self.tileOverlay = tileOverlay }
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
} 