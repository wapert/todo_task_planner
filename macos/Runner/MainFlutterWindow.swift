import Cocoa
import EventKit
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let eventStore = EKEventStore()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerSystemCalendarChannel(controller: flutterViewController)

    super.awakeFromNib()
  }

  private func registerSystemCalendarChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "todo_task_planner/system_calendar",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "Calendar service unavailable", details: nil))
        return
      }

      switch call.method {
      case "calendars":
        self.handleCalendars(result: result)
      case "createEvents":
        self.handleCreateEvents(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func requestCalendarAccess(completion: @escaping (Bool, Error?) -> Void) {
    if #available(macOS 14.0, *) {
      eventStore.requestFullAccessToEvents(completion: completion)
    } else {
      eventStore.requestAccess(to: .event, completion: completion)
    }
  }

  private func handleCalendars(result: @escaping FlutterResult) {
    requestCalendarAccess { [weak self] granted, error in
      guard let self else { return }
      if let error {
        DispatchQueue.main.async {
          result(FlutterError(code: "calendar_error", message: error.localizedDescription, details: nil))
        }
        return
      }
      guard granted else {
        DispatchQueue.main.async {
          result(FlutterError(code: "permission_denied", message: "Calendar permission was not granted.", details: nil))
        }
        return
      }

      let calendars = self.eventStore.calendars(for: .event).map { calendar in
        [
          "id": calendar.calendarIdentifier,
          "name": calendar.title,
          "accountName": calendar.source.title,
          "accountType": "\(calendar.source.sourceType.rawValue)",
          "isReadOnly": !calendar.allowsContentModifications,
          "isDefault": calendar.calendarIdentifier == self.eventStore.defaultCalendarForNewEvents?.calendarIdentifier
        ] as [String: Any]
      }

      DispatchQueue.main.async {
        result(calendars)
      }
    }
  }

  private func handleCreateEvents(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let calendarId = arguments["calendarId"] as? String,
      let rawEvents = arguments["events"] as? [[String: Any]]
    else {
      result(FlutterError(code: "bad_args", message: "Missing calendarId or events.", details: nil))
      return
    }

    requestCalendarAccess { [weak self] granted, error in
      guard let self else { return }
      if let error {
        DispatchQueue.main.async {
          result(FlutterError(code: "calendar_error", message: error.localizedDescription, details: nil))
        }
        return
      }
      guard granted else {
        DispatchQueue.main.async {
          result(FlutterError(code: "permission_denied", message: "Calendar permission was not granted.", details: nil))
        }
        return
      }
      guard let calendar = self.eventStore.calendar(withIdentifier: calendarId) else {
        DispatchQueue.main.async {
          result(FlutterError(code: "calendar_missing", message: "Selected calendar was not found.", details: nil))
        }
        return
      }

      do {
        for rawEvent in rawEvents {
          let event = EKEvent(eventStore: self.eventStore)
          event.calendar = calendar
          event.title = rawEvent["title"] as? String ?? "Task"
          event.notes = rawEvent["notes"] as? String
          event.isAllDay = rawEvent["allDay"] as? Bool ?? false
          let startSeconds = rawEvent["start"] as? Double ?? Date().timeIntervalSince1970
          let endSeconds = rawEvent["end"] as? Double ?? startSeconds + 3600
          event.startDate = Date(timeIntervalSince1970: startSeconds)
          event.endDate = Date(timeIntervalSince1970: endSeconds)
          try self.eventStore.save(event, span: .thisEvent)
        }
        DispatchQueue.main.async {
          result(rawEvents.count)
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "save_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }
}
