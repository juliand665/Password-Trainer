import SwiftUI
import UserNotifications
import UserDefault

let notificationID = "reminder"
let keychainID = "com.juliand665.Password-Trainer"
let notificationCenter = UNUserNotificationCenter.current()

struct ContentView: View {
	@State var password = "password123"
	@State var guess = ""
	@State var isPeeking = false
	@State var wrongGuessTrigger = false
	@AppStorage("streak") var streak = 0
	@UserDefault.State("nextReminder") var nextReminder: Date?
	@FocusState var isPasswordFieldFocused: Bool
	
	private let keychain = OSKeychain.instance
	
    var body: some View {
		GroupBox {
			VStack {
				Text("Enter Password")
				
				SecureField("Guess", text: $guess)
					.phaseAnimator([false, true], trigger: wrongGuessTrigger) { view, phase in
						view
							.offset(x: phase ? 5 : 0)
					} animation: { phase in
						phase
						? .easeOut(duration: 0)
						: .spring(.init(settlingDuration: 0.5, dampingRatio: 0.05))
					}
					.onSubmit(submit)
					.textFieldStyle(.roundedBorder)
					.focused($isPasswordFieldFocused)
				
				HStack {
					let _ = password // otherwise the popover seems to capture the wrong one
					Button("Peek") {
						isPeeking = true
					}
					.popover(isPresented: $isPeeking) {
						Text(password)
							.monospaced()
							.padding()
					}
					
					Button("Submit", action: submit)
						.buttonStyle(.borderedProminent)
					
					Button("Change") {
						password = guess
						try! keychain.store(password, forKey: keychainID)
						streak = 0
					}
				}
				.fixedSize()
				.buttonStyle(.bordered)
				
				Divider()
				
				Text("Streak: \(streak)")
					.bold()
				if let nextReminder {
					TimelineView(.everyMinute) { _ in
						if nextReminder > .now {
							Text("Next reminder \(nextReminder, format: .relative(presentation: .named))")
						} else {
							Text("No reminder scheduled—make a guess!")
						}
					}
				}
			}
		}
		.groupBoxStyle(.hiddenOnMac)
		.frame(maxWidth: 300)
        .padding()
		.task {
			isPasswordFieldFocused = true // defaultFocus didn't work
			if let stored = try! keychain.loadString(forKey: keychainID) {
				password = stored
			} else {
				print("nothing stored!")
			}
		}
    }
	
	func submit() {
		if guess == password {
			print("correct!")
			guess = ""
			let reminderDelay = 60 * pow(2, Double(streak))
			let newReminder = Date(timeIntervalSinceNow: reminderDelay)
			if let nextReminder, nextReminder > .now, nextReminder < newReminder {
				print("already got a reminder scheduled!")
			} else {
				streak += 1
				nextReminder = newReminder
				Task { await scheduleReminder(at: newReminder) }
			}
		} else {
			wrongGuessTrigger.toggle()
			streak = Int(Double(streak) * 0.6)
		}
	}
	
	func scheduleReminder(at time: Date) async {
		try! await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
		
		let content = UNMutableNotificationContent()
		content.title = "Vibe Check!"
		content.badge = 1
		content.sound = .default
		let trigger = UNTimeIntervalNotificationTrigger(timeInterval: time.timeIntervalSinceNow, repeats: false)
		let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
		try! await notificationCenter.setBadgeCount(0)
		notificationCenter.removeAllDeliveredNotifications()
		try! await notificationCenter.add(request)
	}
}

extension GroupBoxStyle where Self == HiddenOnMacGroupBoxStyle {
	static var hiddenOnMac: Self { .init() }
}

struct HiddenOnMacGroupBoxStyle: GroupBoxStyle {
	func makeBody(configuration: Configuration) -> some View {
#if os(macOS)
		configuration.content
#else
		GroupBox(configuration)
#endif
	}
}

#Preview {
    ContentView()
}
