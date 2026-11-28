import Foundation

/// The spoken name of a theme or sticker for VoiceOver ("Sweet treats
/// frame", "Unicorn"), from the slug in its file or asset name. Unknown slugs
/// fall back to the slug itself, capitalized, so a new picture still reads.
nonisolated enum DisplayName {
    static func of(_ slug: String) -> String {
        switch slug {
        // Frames and covers (Frames/, Covers/)
        case "adventure": String(localized: "Adventure")
        case "animals": String(localized: "Animals")
        case "dinosaurs": String(localized: "Dinosaurs")
        case "garden": String(localized: "Garden")
        case "lavender": String(localized: "Lavender")
        case "ocean": String(localized: "Ocean")
        case "party": String(localized: "Party")
        case "rainbow": String(localized: "Rainbow")
        case "space": String(localized: "Space")
        case "sweet-treats": String(localized: "Sweet treats")
        // Stickers (StickerKind)
        case "star": String(localized: "Star")
        case "heart": String(localized: "Heart")
        case "flower": String(localized: "Flower")
        case "sun": String(localized: "Sun")
        case "moon": String(localized: "Moon")
        case "crown": String(localized: "Crown")
        case "balloons": String(localized: "Balloons")
        case "gift": String(localized: "Gift")
        case "cupcake": String(localized: "Cupcake")
        case "strawberry": String(localized: "Strawberry")
        case "cherries": String(localized: "Cherries")
        case "butterfly": String(localized: "Butterfly")
        case "rocket": String(localized: "Rocket")
        case "unicorn": String(localized: "Unicorn")
        case "cat": String(localized: "Cat")
        case "dog": String(localized: "Dog")
        case "bear": String(localized: "Bear")
        case "panda": String(localized: "Panda")
        case "rabbit": String(localized: "Rabbit")
        default: slug.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }
}
