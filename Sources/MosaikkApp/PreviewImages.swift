import CoreGraphics
import Foundation
import Observation

/// Decoded and filtered pictures for the canvas and the sidebar. Requests are answered from the cache straight away;
/// anything missing is prepared in the background and `revision` changes when it is ready, so the canvas redraws.
/// While a new version is being prepared, the closest version already in memory is shown instead of a blank.
@MainActor @Observable
final class PreviewImages {
    private(set) var revision = 0
    @ObservationIgnored var originals: [UUID: Data] = [:]

    @ObservationIgnored private var cache: [ImageRequest: Entry] = [:]
    @ObservationIgnored private var cost = 0
    @ObservationIgnored private var clock = 0
    @ObservationIgnored private var pending: Set<ImageRequest> = []
    @ObservationIgnored private var queue: [ImageRequest] = []
    @ObservationIgnored private var running = 0
    private let budget = 600 * 1024 * 1024

    private struct Entry {
        var image: CGImage
        var used: Int
        var cost: Int
    }

    /// The picture for `request`, or the nearest one available while it loads.
    func image(_ request: ImageRequest) -> CGImage? {
        clock += 1
        if var entry = cache[request] {
            entry.used = clock
            cache[request] = entry
            return entry.image
        }
        load(request)
        return nearest(request)
    }

    /// A small upright copy without any look, for the library.
    func thumbnail(_ asset: UUID) -> CGImage? {
        image(ImageRequest(asset: asset, look: Look(), pixels: 256))
    }

    private func nearest(_ request: ImageRequest) -> CGImage? {
        // The same look at another size, else the plain picture: never a different filter, which would mislead.
        let pool = cache.filter { $0.key.asset == request.asset && $0.key.backdrop == request.backdrop && $0.key.look == request.look }
        let fallback = pool.isEmpty ? cache.filter { $0.key.asset == request.asset && $0.key.backdrop == nil && $0.key.look == Look() } : pool
        return fallback.min { a, b in
            score(a.key.pixels, request.pixels) < score(b.key.pixels, request.pixels)
        }?.value.image
    }

    private func score(_ pixels: Int, _ wanted: Int) -> Int {
        pixels <= wanted ? (wanted - pixels) : (pixels - wanted) * 2
    }

    private func load(_ request: ImageRequest) {
        guard !pending.contains(request), originals[request.asset] != nil else { return }
        pending.insert(request)
        queue.append(request)
        pump()
    }

    private func pump() {
        while running < 4, !queue.isEmpty {
            // Newest first: the latest slider position matters more than the ones passed on the way.
            let request = queue.removeLast()
            guard let data = originals[request.asset] else {
                pending.remove(request)
                continue
            }
            running += 1
            let base = baseImage(for: request)
            Task.detached(priority: .userInitiated) {
                let image: CGImage?
                if let base {
                    image = request.backdrop.map { LookRenderer.background(base, blur: $0.blur, dim: $0.dim) } ?? LookRenderer.apply(request.look, to: base)
                } else {
                    image = Renderer.image(for: request, data: data)
                }
                await MainActor.run {
                    self.finish(request, image)
                }
            }
        }
        // Drop stale requests when the queue grows, such as after a fast slider drag.
        if queue.count > 24 {
            for request in queue.prefix(queue.count - 24) { pending.remove(request) }
            queue.removeFirst(queue.count - 24)
        }
    }

    /// An unfiltered decode at the same size, so a look change doesn't decode the file again.
    private func baseImage(for request: ImageRequest) -> CGImage? {
        guard request.look != Look() || request.backdrop != nil else { return nil }
        return cache[ImageRequest(asset: request.asset, look: Look(), pixels: request.pixels)]?.image
    }

    private func finish(_ request: ImageRequest, _ image: CGImage?) {
        running -= 1
        pending.remove(request)
        if let image {
            let bytes = image.bytesPerRow * image.height
            clock += 1
            cache[request] = Entry(image: image, used: clock, cost: bytes)
            cost += bytes
            // Keep the unfiltered decode too, so later look changes are quick.
            if request.look != Look(), request.backdrop == nil, cache[ImageRequest(asset: request.asset, look: Look(), pixels: request.pixels)] == nil {
                load(ImageRequest(asset: request.asset, look: Look(), pixels: request.pixels))
            }
            evict()
            revision += 1
        }
        pump()
    }

    #if DEBUG
    func debugCount(_ asset: UUID) -> (cached: Int, filtered: Int, pending: Int, queued: Int, running: Int) {
        let mine = cache.keys.filter { $0.asset == asset }
        return (mine.count, mine.filter { $0.look != Look() }.count, pending.count, queue.count, running)
    }
    #endif

    private func evict() {
        guard cost > budget else { return }
        for (key, entry) in cache.sorted(by: { $0.value.used < $1.value.used }) {
            guard cost > budget * 3 / 4 else { break }
            cache[key] = nil
            cost -= entry.cost
        }
    }
}
