import Foundation

public struct FollowState: Sendable, Equatable {
    public internal(set) var held: ReceivedPosition?
    public internal(set) var shown: BusPosition?
    public internal(set) var noRecentPosition: Bool

    public init() {
        held = nil
        shown = nil
        noRecentPosition = false
    }
}

public func advance(_ state: FollowState, target: String, incoming: BusPosition?, now: Int) -> FollowState {
    var next = state

    if let incoming, isLive(incoming, now: now) {
        next.held = keepTheNewer(state.held, target: target, incoming: incoming)
    }

    if let held = next.held, held.target == target, isLive(held.bus, now: now) {
        next.shown = held.bus
        next.noRecentPosition = false
    } else {
        next.shown = nil
        next.noRecentPosition = true
    }

    return next
}
