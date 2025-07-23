import Foundation

extension Float {
    static func split(from string: String) -> [Float]? {
        let comps = string.split(separator: " ").compactMap { Float($0) }
        return comps.count == 3 ? comps : nil
    }
}
