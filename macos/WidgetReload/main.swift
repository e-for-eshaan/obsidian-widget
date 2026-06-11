import WidgetKit

let reloadSemaphore = DispatchSemaphore(value: 0)

WidgetCenter.shared.reloadAllTimelines()

DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
    reloadSemaphore.signal()
}

reloadSemaphore.wait()
