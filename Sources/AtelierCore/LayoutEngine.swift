import Foundation

public struct PhotoFrame: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var rect: CGRect
}

public struct ImagePlacement: Sendable {
    public var size: CGSize
    public var offset: CGSize
    public init(photo: Photo, in frame: CGSize) {
        let rotated = photo.quarterTurns % 2 != 0
        let width = Double(rotated ? photo.pixelHeight : photo.pixelWidth)
        let height = Double(rotated ? photo.pixelWidth : photo.pixelHeight)
        let factor = (photo.fit == .fill ? max(frame.width / width, frame.height / height) : min(frame.width / width, frame.height / height)) * photo.zoom
        size = CGSize(width: Double(photo.pixelWidth) * factor, height: Double(photo.pixelHeight) * factor)
        offset = CGSize(width: max(0, width * factor - frame.width) * 0.5 * photo.panX,
                        height: max(0, height * factor - frame.height) * 0.5 * photo.panY)
    }
}

public enum LayoutEngine {
    public static func frames(for project: Project) -> [PhotoFrame] {
        guard !project.photos.isEmpty else { return [] }
        let width = Double(project.width), height = Double(project.height)
        let margin = min(project.margin, min(width, height) * 0.15)
        let area = CGRect(x: margin, y: margin, width: width - margin * 2, height: height - margin * 2)
        switch project.layout {
        case .grid: return grid(project.photos, in: area, columns: project.columns, spacing: project.spacing)
        case .editorial:
            guard project.photos.count > 1 else { return grid(project.photos, in: area, columns: 1, spacing: 0) }
            let gap = min(project.spacing, area.width * 0.05)
            let leading = (area.width - gap) * 0.58
            return [PhotoFrame(id: project.photos[0].id, rect: CGRect(x: area.minX, y: area.minY, width: leading, height: area.height))]
                + grid(Array(project.photos.dropFirst()), in: CGRect(x: area.minX + leading + gap, y: area.minY, width: area.width - leading - gap, height: area.height), columns: project.columns, spacing: project.spacing)
        case .columns: return weighted(project.photos, in: area, vertical: true, columns: project.columns, spacing: project.spacing)
        case .rows: return weighted(project.photos, in: area, vertical: false, columns: project.columns, spacing: project.spacing)
        }
    }

    private static func autoColumns(_ photos: [Photo], area: CGRect) -> Int {
        let average = photos.reduce(0.0) { $0 + log($1.aspect) } / Double(photos.count)
        return (1...min(photos.count, 20)).min { a, b in
            func score(_ c: Int) -> Double {
                let rows = Int(ceil(Double(photos.count) / Double(c)))
                let aspect = (area.width / Double(c)) / (area.height / Double(rows))
                return abs(log(aspect) - average) + Double(rows * c - photos.count) / Double(photos.count) * 0.9
            }
            return score(a) < score(b)
        } ?? 1
    }

    private static func grid(_ photos: [Photo], in area: CGRect, columns: Int, spacing: Double) -> [PhotoFrame] {
        let cols = columns == 0 ? autoColumns(photos, area: area) : min(columns, photos.count)
        let rows = Int(ceil(Double(photos.count) / Double(cols)))
        let gap = min(spacing, min(area.width / Double(cols), area.height / Double(rows)) * 0.25)
        let height = (area.height - Double(rows - 1) * gap) / Double(rows)
        return photos.enumerated().map { index, photo in
            let row = index / cols, col = index % cols
            let count = min(cols, photos.count - row * cols)
            let width = (area.width - Double(count - 1) * gap) / Double(count)
            return PhotoFrame(id: photo.id, rect: CGRect(x: area.minX + Double(col) * (width + gap), y: area.minY + Double(row) * (height + gap), width: width, height: height))
        }
    }

    private static func weighted(_ photos: [Photo], in area: CGRect, vertical: Bool, columns: Int, spacing: Double) -> [PhotoFrame] {
        let groups = min(photos.count, columns > 0 ? columns : max(1, Int(sqrt(Double(photos.count)))))
        let lengths = (0..<groups).map { group in photos.enumerated().filter { $0.offset % groups == group }.map(\.element) }
        let cross = vertical ? area.width : area.height
        let along = vertical ? area.height : area.width
        let largestGroup = lengths.map(\.count).max() ?? 1
        let gap = min(spacing, min(cross / Double(groups), along / Double(largestGroup)) * 0.25)
        let breadth = (cross - Double(groups - 1) * gap) / Double(groups)
        var result: [PhotoFrame] = []
        for (group, items) in lengths.enumerated() {
            let weights = items.map { min(2.5, max(0.4, vertical ? 1 / $0.aspect : $0.aspect)) }
            let sum = weights.reduce(0, +)
            var cursor = 0.0
            for (index, item) in items.enumerated() {
                let length = (along - Double(items.count - 1) * gap) * weights[index] / sum
                let rect = vertical
                    ? CGRect(x: area.minX + Double(group) * (breadth + gap), y: area.minY + cursor, width: breadth, height: length)
                    : CGRect(x: area.minX + cursor, y: area.minY + Double(group) * (breadth + gap), width: length, height: breadth)
                result.append(PhotoFrame(id: item.id, rect: rect))
                cursor += length + gap
            }
        }
        return result
    }
}
