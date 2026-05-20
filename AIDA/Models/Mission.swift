import Foundation

struct Mission {
    let title: String
    let subtitle: String
    let estimatedDuration: String
}

extension Mission {
    static let placeholders: [Mission] = [
        Mission(title: "Esplorativo",
                subtitle: "Scopri angoli nascosti della città a passo lento.",
                estimatedDuration: "45 min"),
        Mission(title: "Corsa",
                subtitle: "Una missione dinamica con tappe a ritmo sostenuto.",
                estimatedDuration: "30 min")
    ]
}
