import Foundation

struct CreatureStyle: Identifiable, Sendable {
    let id: String
    let displayName: String
    let frames: [[String]]

    static let frameCount = 3
    private static let selectionKey = "selectedCreatureStyle"

    static let all = [
        CreatureStyle(
            id: "blob",
            displayName: "Blob",
            frames: [
                [
                    "................",
                    "......B..B......",
                    ".....BBBBBB.....",
                    "....BBBBBBBB....",
                    "...BBBBBBBBBB...",
                    "...BBBBBBBBBB...",
                    "..BBBBBBBBBBBB..",
                    "..BBBBBBBBBBBB..",
                    "..BBBBBBBBBBBB..",
                    "..BBBBBBBBBBBB..",
                    "...BBBBBBBBBB...",
                    "....BBBBBBBB....",
                    ".....BB..BB.....",
                    "......B..B......",
                    "................",
                    "................"
                ],
                [
                    "................",
                    "................",
                    "....BB....BB....",
                    "...BBBBBBBBBB...",
                    "..BBBBBBBBBBBB..",
                    ".BBBBBBBBBBBBBB.",
                    ".BBBBBBBBBBBBBB.",
                    ".BBBBBBBBBBBBBB.",
                    ".BBBBBBBBBBBBBB.",
                    "..BBBBBBBBBBBB..",
                    "...BBBBBBBBBB...",
                    "..BBBB..BBBB....",
                    "...BB....BB.....",
                    "................",
                    "................",
                    "................"
                ],
                [
                    "...B........B...",
                    "..BB......BB....",
                    "....BB....BB....",
                    "...BBBBBBBBBB...",
                    "..BBBBBBBBBBBB..",
                    ".BBBBBBBBBBBBBB.",
                    ".BBBBBBBBBBBBBB.",
                    ".BBBBBBBBBBBBBB.",
                    "..BBBBBBBBBBBB..",
                    "...BBBBBBBBBB...",
                    "..BB..BBBB..BB..",
                    ".BB....BB....BB.",
                    "B......BB......B",
                    "................",
                    "................",
                    "................"
                ]
            ]
        ),
        CreatureStyle(
            id: "sprout",
            displayName: "Sprout",
            frames: [
                [
                    "................",
                    ".....BBBB.......",
                    "....BBBBBB......",
                    "......BB........",
                    "....BBBBBBBB....",
                    "...BBBBBBBBBB...",
                    "..BBBBBBBBBBBB..",
                    "..BBBBBBBBBBBB..",
                    "..BBBBBBBBBBBB..",
                    "...BBBBBBBBBB...",
                    "....BBBBBBBB....",
                    ".....BBBBBB.....",
                    ".....BB..BB.....",
                    "......B..B......",
                    "................",
                    "................"
                ],
                [
                    "................",
                    "................",
                    "....BBBB........",
                    "...BBBBBB.......",
                    ".....BB.........",
                    "...BBBBBBBBBB...",
                    "..BBBBBBBBBBBB..",
                    ".BBBBBBBBBBBBBB.",
                    ".BBBBBBBBBBBBBB.",
                    ".BBBBBBBBBBBBBB.",
                    "..BBBBBBBBBBBB..",
                    "...BBBBBBBBBB...",
                    "....BBB..BBB....",
                    ".....B....B.....",
                    "................",
                    "................"
                ],
                [
                    "................",
                    ".......BBBB.....",
                    "......BBBBBB....",
                    "........BB......",
                    "....BBBBBBBB....",
                    "...BBBBBBBBBB...",
                    "..BBBBBBBBBBBB..",
                    ".BBBBBBBBBBBBBB.",
                    ".BBBBBBBBBBBBBB.",
                    "..BBBBBBBBBBBB..",
                    "...BBBBBBBBBB...",
                    "..BB..BBBB..BB..",
                    ".BB....BB....BB.",
                    "B......BB......B",
                    "................",
                    "................"
                ]
            ]
        ),
        CreatureStyle(
            id: "bunny",
            displayName: "Bunny",
            frames: [
                [
                    "....BB....BB....",
                    "....BB....BB....",
                    "...BBBB..BBBB...",
                    "....BBBBBBBB....",
                    "...BBBBBBBBBB...",
                    "..BBBBBBBBBBBB..",
                    ".BBBBBBBBBBBBBB.",
                    ".BBBBBBBBBBBBBB.",
                    ".BBBBBBBBBBBBBB.",
                    "..BBBBBBBBBBBB..",
                    "...BBBBBBBBBB...",
                    "....BBBBBBBB....",
                    "....BBB..BBB....",
                    ".....B....B.....",
                    "................",
                    "................"
                ],
                [
                    "................",
                    "...BBB....BBB...",
                    "....BBB..BBB....",
                    "....BBBBBBBB....",
                    "...BBBBBBBBBB...",
                    "..BBBBBBBBBBBB..",
                    ".BBBBBBBBBBBBBB.",
                    ".BBBBBBBBBBBBBB.",
                    ".BBBBBBBBBBBBBB.",
                    ".BBBBBBBBBBBBBB.",
                    "..BBBBBBBBBBBB..",
                    "...BBBBBBBBBB...",
                    "...BBBB..BBBB...",
                    "....BB....BB....",
                    "................",
                    "................"
                ],
                [
                    "...BB......BB...",
                    "..BBB......BBB..",
                    "...BBBB..BBBB...",
                    "....BBBBBBBB....",
                    "...BBBBBBBBBB...",
                    "..BBBBBBBBBBBB..",
                    ".BBBBBBBBBBBBBB.",
                    ".BBBBBBBBBBBBBB.",
                    ".BBBBBBBBBBBBBB.",
                    "..BBBBBBBBBBBB..",
                    ".BB.BBBBBBBB.BB.",
                    "BB....BBBB....BB",
                    "B......BB......B",
                    "................",
                    "................",
                    "................"
                ]
            ]
        )
    ]

    static var defaultStyle: CreatureStyle {
        all[0]
    }

    static func resolve(id: String?) -> CreatureStyle {
        all.first { $0.id == id } ?? defaultStyle
    }

    static func load(from defaults: UserDefaults = .standard) -> CreatureStyle {
        resolve(id: defaults.string(forKey: selectionKey))
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(id, forKey: Self.selectionKey)
    }
}
