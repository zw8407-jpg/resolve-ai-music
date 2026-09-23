import Testing
@testable import ResolveAIMusic

struct PresetVariationTests {
    @Test func allStylesHaveDistinctLocalAlternatives() {
        for style in Presets.names {
            let choices = [Presets.descriptions[style]!]
                + (Presets.alternatives[style] ?? [])
            #expect(Set(choices).count >= 3)
            for current in choices {
                let next = Presets.randomDescription(for: style, excluding: current)
                #expect(next != current)
                #expect(choices.contains(next))
            }
        }
        #expect(Presets.randomDescription(for: "unknown", excluding: "保留自定义") == "保留自定义")
    }
}
