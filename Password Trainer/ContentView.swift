import SwiftUI

struct ContentView: View {
	@State var password = "password123"
	@State var guess = ""
	@State var isPeeking = false
	@State var wrongGuessTrigger = false
	
	private let keychain = OSKeychain.instance
	
    var body: some View {
        VStack {
			Text("Enter Password")
			
			TextField("Guess", text: $guess)
				.phaseAnimator([false, true], trigger: wrongGuessTrigger) { view, phase in
					view
						.offset(x: phase ? 5 : 0)
				} animation: { phase in
					phase 
					? .easeOut(duration: 0)
					: .spring(.init(settlingDuration: 0.5, dampingRatio: 0.05))
				}
				.onSubmit(submit)
			
			HStack {
				Button("Peek") {
					isPeeking = true
				}
				.popover(isPresented: $isPeeking) {
					Text(password)
						.monospaced()
						.padding()
				}
				
				Button("Submit", action: submit)
				
				Button("Change") {
					password = guess
					try! keychain.store(password, forKey: "com.juliand665.Password-Trainer")
				}
			}
			.fixedSize()
        }
		.frame(maxWidth: 300)
        .padding()
		.task {
			password = try! keychain.loadString(forKey: "com.juliand665.Password-Trainer") ?? password
		}
    }
	
	func submit() {
		if guess == password {
			print("correct!")
			exit(0)
		} else {
			wrongGuessTrigger.toggle()
		}
	}
}

#Preview {
    ContentView()
}
