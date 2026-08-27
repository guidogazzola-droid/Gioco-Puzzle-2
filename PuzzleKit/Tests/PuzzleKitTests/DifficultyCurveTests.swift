import Testing
@testable import PuzzleKit

struct DifficultyCurveTests {

    @Test("the board never asks for more colours than it can hold")
    func colorsFitTheBoard() {
        for track in LevelTrack.allCases {
            for level in 1...400 {
                let parameters = DifficultyCurve.parameters(level: level, track: track)
                #expect(parameters.colors >= 3)
                #expect(parameters.colors * 2 <= parameters.playableCells)
                #expect(parameters.blocked <= parameters.cells / 6)
            }
        }
    }

    @Test("difficulty grows overall without growing every single step")
    func curveTrendsUpward() {
        for track in LevelTrack.allCases {
            let early = DifficultyCurve.parameters(level: 3, track: track)
            let middle = DifficultyCurve.parameters(level: 60, track: track)
            let late = DifficultyCurve.parameters(level: 150, track: track)
            #expect(early.colors < middle.colors)
            #expect(middle.colors <= late.colors)
            #expect(early.playableCells < late.playableCells)
        }
    }

    @Test("boss levels are bigger and breathers are easier")
    func pacingBeatsExist() {
        #expect(DifficultyCurve.isBoss(level: 10))
        #expect(DifficultyCurve.isBoss(level: 120))
        #expect(!DifficultyCurve.isBoss(level: 11))
        #expect(DifficultyCurve.isBreather(level: 7))
        // A boss beats a breather when they collide.
        #expect(!DifficultyCurve.isBreather(level: 70))

        let boss = DifficultyCurve.parameters(level: 50, track: .free)
        let before = DifficultyCurve.parameters(level: 49, track: .free)
        #expect(boss.isBoss)
        #expect(boss.colors > before.colors)

        let breather = DifficultyCurve.parameters(level: 56, track: .free)
        let neighbour = DifficultyCurve.parameters(level: 55, track: .free)
        #expect(breather.isBreather)
        #expect(breather.colors < neighbour.colors)
    }

    @Test("the Pro track is strictly harder than the free track at the same level")
    func proIsHarder() {
        for level in [1, 10, 40, 90] {
            let free = DifficultyCurve.parameters(level: level, track: .free)
            let pro = DifficultyCurve.parameters(level: level, track: .pro)
            #expect(pro.colors > free.colors)
            #expect(pro.playableCells > free.playableCells)
        }
    }

    @Test("boards stay within what a phone screen can show")
    func boardsStayOnScreen() {
        for track in LevelTrack.allCases {
            for level in 1...400 {
                let parameters = DifficultyCurve.parameters(level: level, track: track)
                #expect(parameters.width <= DifficultyCurve.maximumSide)
                #expect(parameters.height <= DifficultyCurve.maximumSide)
                #expect(parameters.width >= 5 && parameters.height >= 5)
            }
        }
    }

    @Test("level numbers below one are clamped rather than crashing")
    func handlesDegenerateInput() {
        let parameters = DifficultyCurve.parameters(level: -5, track: .free)
        #expect(parameters.colors >= 3)
        #expect(LevelValidator.validate(LevelGenerator.generate(level: 0, track: .free)) == nil)
    }
}
