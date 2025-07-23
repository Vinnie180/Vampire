import UIKit
import SpriteKit

class GameViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // ⚠️ Safely cast to SKView (avoids that “found nil” crash)
        guard let skView = view as? SKView else {
            fatalError("View is not an SKView!")
        }

        // 1️⃣ Create your scene at the SKView’s size
        let scene = GameScene(size: skView.bounds.size)

        // 2️⃣ Make the scene always fill the screen (no stretching)
        scene.scaleMode = .aspectFit

        // 3️⃣ Present it
        skView.presentScene(scene)

        // (Optional debugging overlays)
        skView.ignoresSiblingOrder = true
        skView.showsFPS = true
        skView.showsNodeCount = true
    }

    // Support all orientations (optional)
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
