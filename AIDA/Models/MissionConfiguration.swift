import Foundation

struct MissionConfiguration {
    enum AgeMode {
        case single(age: Int)
        case group(min: Int, max: Int)
    }

    let ageMode: AgeMode
    let durationMinutes: Int
    let photoEnigmasEnabled: Bool
    let area: MissionArea
}
