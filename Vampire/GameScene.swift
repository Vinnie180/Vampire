import SpriteKit
import GameplayKit

// MARK: –––––––––––––––––––– Constants & EnemyTypes –––––––––––––––––––––

struct GameConstants {
    // NEW: Map constants
    struct Map {
        static let size          = CGSize(width: 3000, height: 3000)
        static let backgroundColor = UIColor.darkGray
        static let edgeColor     = UIColor.green
        static let edgeWidth: CGFloat = 40.0
    }
    
    struct Player {
        static var size       = CGSize(width: 40, height: 40)
        static var color      = UIColor.white
        static var baseSpeed: CGFloat     = 200      // points per second
        static var baseFireRate: TimeInterval = 0.5  // seconds between shots
        static var baseDamage: Int        = 1
        static var baseHP: Int            = 5
        static var baseRange: CGFloat     = 500      // max bullet travel distance
    }
    struct Bullet {
        static let radius: CGFloat = 4
        static let color           = UIColor.yellow
        static let speed: CGFloat  = 600
    }
    struct Enemy {
        struct EnemyType {
            let name: String
            let color: UIColor
            var baseHP: Int
            let xpValue: Int
            let canShoot: Bool
            let speed: CGFloat
        }
        static var EnemyTypes: [EnemyType] = [
            .init(name:"red",   color:.red,   baseHP: 5,  xpValue:1, canShoot:false, speed:80),
            .init(name:"blue",  color:.blue,  baseHP:10, xpValue:2, canShoot:true,  speed:60),
            .init(name:"green", color:.green, baseHP:15, xpValue:3, canShoot:true,  speed:40)
        ]
    }
    struct Spawn {
        static let rate: TimeInterval             = 0.8  // spawn every 0.8s
        static let indicatorDuration: TimeInterval = 1.0
    }
    struct Upgrade {
        static let xpPerLevel = 10
    }
}

// MARK: –––––––––––––––––––– Player State –––––––––––––––––––––

class PlayerStats {
    var hp: Int
    var damage: Int
    var fireRate: TimeInterval
    var speed: CGFloat
    var range: CGFloat    // bullet reach

    init() {
        hp       = GameConstants.Player.baseHP
        damage   = GameConstants.Player.baseDamage
        fireRate = GameConstants.Player.baseFireRate
        speed    = GameConstants.Player.baseSpeed
        range    = GameConstants.Player.baseRange
    }
}

// MARK: –––––––––––––––––––– GameScene –––––––––––––––––––––

class GameScene: SKScene {

    // MARK: –––––––––––––––––––– Nodes –––––––––––––––––––––
    
    // NEW: World and Camera nodes for the scrollable map
    private var world: SKNode!
    private var cameraNode: SKCameraNode!

    private var player: SKSpriteNode!
    private var joystickBase: SKShapeNode!
    private var joystickKnob: SKShapeNode!

    // MARK: –––––––––––––––––––– State –––––––––––––––––––––

    private var lastSpawnTime: TimeInterval = 0
    private var lastFireTime: TimeInterval  = 0

    private var enemies: [SKSpriteNode] = []
    private var bullets: [SKShapeNode]  = []

    private let stats = PlayerStats()

    private var xp: Int = 0 {
        didSet { checkLevelUp() }
    }

    private var kills: Int = 0 {
        didSet {
            if kills > 0, kills % 30 == 0 {
                for i in 0..<GameConstants.Enemy.EnemyTypes.count {
                    GameConstants.Enemy.EnemyTypes[i].baseHP += 1
                }
            }
            if kills > 0, kills % 10 == 0 {
                randomUpgrade(reason: "Kill Bonus")
            }
        }
    }

    // MARK: –––––––––––––––––––– Scene Setup –––––––––––––––––––––

    override func didMove(to view: SKView) {
        backgroundColor = .black // Fallback color
        anchorPoint     = CGPoint(x:0.5, y:0.5)

        // Setup the world and camera
        setupWorld()
        setupCamera()
        
        // Setup game elements
        setupMap()
        setupPlayer()
        setupJoystick()
    }
    
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        
        // Reposition joystick if screen size changes (e.g., rotation)
        joystickBase?.position = CGPoint(
          x: -size.width/2 + 80,
          y: -size.height/2 + 80
        )
    }

    private func setupWorld() {
        world = SKNode()
        world.name = "world"
        addChild(world)
    }
    
    private func setupCamera() {
        cameraNode = SKCameraNode()
        cameraNode.position = .zero
        self.camera = cameraNode
        addChild(cameraNode) // Add camera to scene, not world
    }
    
    private func setupMap() {
        let mapSize = GameConstants.Map.size
        
        // Create the background
        let background = SKShapeNode(rectOf: mapSize)
        background.fillColor = GameConstants.Map.backgroundColor
        background.strokeColor = .clear
        background.zPosition = -100 // Ensure it's behind everything
        world.addChild(background)
        
        // Create the thick edge
        let edge = SKShapeNode(rectOf: mapSize)
        edge.fillColor = .clear
        edge.strokeColor = GameConstants.Map.edgeColor
        edge.lineWidth = GameConstants.Map.edgeWidth
        edge.zPosition = -99
        world.addChild(edge)
    }

    private func setupPlayer() {
        player = SKSpriteNode(color: GameConstants.Player.color,
                              size: GameConstants.Player.size)
        player.position = .zero
        world.addChild(player) // Add player to the world
    }

    private func setupJoystick() {
        joystickBase = SKShapeNode(circleOfRadius: 50)
        joystickBase.lineWidth   = 2
        joystickBase.strokeColor = .white
        joystickBase.position    = CGPoint(x: -size.width/2 + 80,
                                           y: -size.height/2 + 80)
        joystickBase.name        = "joystickBase"
        // NEW: Add joystick to camera so it stays on screen
        cameraNode.addChild(joystickBase)

        joystickKnob = SKShapeNode(circleOfRadius: 25)
        joystickKnob.fillColor = .white
        joystickKnob.name      = "joystickKnob"
        joystickKnob.position  = .zero
        joystickBase.addChild(joystickKnob)
    }

    // MARK: –––––––––––––––––––– Touch Handling –––––––––––––––––––––

    private var knobActive = false

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        // NEW: Check for touch location within the camera's coordinate space
        let loc = t.location(in: cameraNode)
        if joystickBase.frame.contains(loc) {
            knobActive = true
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard knobActive, let t = touches.first else { return }
        let loc = t.location(in: joystickBase)
        let maxDist: CGFloat = 50
        let angle           = atan2(loc.y, loc.x)
        let dist            = min(maxDist, hypot(loc.x, loc.y))
        joystickKnob.position = CGPoint(x: cos(angle) * dist,
                                        y: sin(angle) * dist)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        knobActive = false
        let moveBack = SKAction.move(to: .zero, duration: 0.2)
        moveBack.timingMode = .easeOut
        joystickKnob.run(moveBack)
    }

    // MARK: –––––––––––––––––––– Main Loop –––––––––––––––––––––

    private var lastUpdateTime: TimeInterval?

    override func update(_ currentTime: TimeInterval) {
        let dt = currentTime - (lastUpdateTime ?? currentTime)
        lastUpdateTime = currentTime

        handlePlayerMovement(delta: dt)
        handleSpawning(time: currentTime)
        handleAutoShoot(time: currentTime)
        moveEnemies(delta: dt)
        checkCollisions()
    }
    
    // NEW: didFinishUpdate is called after all actions are processed
    override func didFinishUpdate() {
        // Center the camera on the player
        cameraNode.position = player.position
        
        // Clamp camera to map boundaries
        clampCameraToMap()
    }

    // MARK: –––––––––––––––––––– Player Movement & Camera –––––––––––––––––––––

    private func handlePlayerMovement(delta dt: TimeInterval) {
        let dx = joystickKnob.position.x / 50
        let dy = joystickKnob.position.y / 50
        let velocity = CGVector(dx: dx * stats.speed * CGFloat(dt),
                                dy: dy * stats.speed * CGFloat(dt))
        
        // Move the player within the world
        player.position.x += velocity.dx
        player.position.y += velocity.dy

        // Clamp player position to map boundaries
        let mapSize = GameConstants.Map.size
        let halfW = mapSize.width / 2 - player.size.width / 2
        let halfH = mapSize.height / 2 - player.size.height / 2
        
        player.position.x = max(-halfW, min(halfW, player.position.x))
        player.position.y = max(-halfH, min(halfH, player.position.y))
    }
    
    private func clampCameraToMap() {
        guard let viewSize = view?.bounds.size else { return }
        
        let mapSize = GameConstants.Map.size
        
        let xRange = SKRange(lowerLimit: -mapSize.width/2 + viewSize.width/2,
                             upperLimit:  mapSize.width/2 - viewSize.width/2)
                             
        let yRange = SKRange(lowerLimit: -mapSize.height/2 + viewSize.height/2,
                             upperLimit:  mapSize.height/2 - viewSize.height/2)
        
        let xConstraint = SKConstraint.positionX(xRange)
        let yConstraint = SKConstraint.positionY(yRange)
        
        // Use constraints for smooth, physics-based clamping
        cameraNode.constraints = [xConstraint, yConstraint]
    }

    // MARK: –––––––––––––––––––– Spawning & Indicator –––––––––––––––––––––

    private func handleSpawning(time currentTime: TimeInterval) {
        if currentTime - lastSpawnTime < GameConstants.Spawn.rate { return }
        lastSpawnTime = currentTime

        // NEW: Spawn relative to the camera's view, in world coordinates
        let cameraPos = cameraNode.position
        let w = size.width/2 + 50  // Spawn slightly off-screen
        let h = size.height/2 + 50
        
        let spawnPoints = [
            CGPoint(x: .random(in: cameraPos.x-w...cameraPos.x+w), y: cameraPos.y-h),
            CGPoint(x: .random(in: cameraPos.x-w...cameraPos.x+w), y: cameraPos.y+h),
            CGPoint(x: cameraPos.x-w, y: .random(in: cameraPos.y-h...cameraPos.y+h)),
            CGPoint(x: cameraPos.x+w, y: .random(in: cameraPos.y-h...cameraPos.y+h))
        ]
        let pos = spawnPoints.randomElement()!

        // indicator
        let dot = SKShapeNode(circleOfRadius: 8)
        dot.fillColor = .red; dot.strokeColor = .clear
        dot.position = pos
        world.addChild(dot) // Add to world

        dot.run(.sequence([
            .wait(forDuration: GameConstants.Spawn.indicatorDuration),
            .removeFromParent(),
            .run { [weak self] in self?.spawnEnemy(at: pos) }
        ]))
    }

    private func spawnEnemy(at pos: CGPoint) {
        let t     = GameConstants.Enemy.EnemyTypes.randomElement()!
        let enemy = SKSpriteNode(color: t.color, size: CGSize(width:30,height:30))
        enemy.name = t.name
        enemy.userData = [
            "hp": t.baseHP,
            "xp": t.xpValue,
            "canShoot": t.canShoot,
            "speed": t.speed
        ]
        enemy.position = pos
        world.addChild(enemy) // Add to world
        enemies.append(enemy)

        if t.canShoot {
            let shootAction = SKAction.run { [weak self] in
                self?.enemyShoot(from: enemy)
            }
            let seq = SKAction.sequence([
                .wait(forDuration: 2.0),
                .repeatForever(.sequence([shootAction, .wait(forDuration: 2.0)]))
            ])
            enemy.run(seq, withKey:"shoot")
        }
    }

    // MARK: –––––––––––––––––––– Shooting –––––––––––––––––––––

    private func handleAutoShoot(time currentTime: TimeInterval) {
        guard currentTime - lastFireTime >= stats.fireRate else { return }
        lastFireTime = currentTime

        let inRange = enemies.filter {
            $0.position.distance(to: player.position) <= stats.range
        }
        guard let target = inRange.min(by: {
            $0.position.distance(to: player.position) <
            $1.position.distance(to: player.position)
        }) else { return }

        fireBullet(at: target.position, damage: stats.damage)
    }

    private func fireBullet(at point: CGPoint, damage: Int) {
        let b = SKShapeNode(circleOfRadius: GameConstants.Bullet.radius)
        b.fillColor = GameConstants.Bullet.color
        b.position = player.position
        b.userData = ["damage": damage]
        world.addChild(b); bullets.append(b) // Add to world

        let dx = point.x - b.position.x
        let dy = point.y - b.position.y
        let len = hypot(dx,dy)
        let ux  = dx/len, uy = dy/len

        let travel   = stats.range
        let moveBy   = CGVector(dx: ux * travel, dy: uy * travel)
        let duration = TimeInterval(travel / GameConstants.Bullet.speed)

        b.run(.sequence([
            .move(by: moveBy, duration: duration),
            .removeFromParent()
        ]))
    }

    private func enemyShoot(from enemy: SKSpriteNode) {
        guard let canShoot = enemy.userData?["canShoot"] as? Bool,
              canShoot else { return }
        let b = SKShapeNode(circleOfRadius: GameConstants.Bullet.radius)
        b.fillColor = .magenta
        b.position = enemy.position
        b.userData = ["damage": 1]
        world.addChild(b); bullets.append(b) // Add to world

        let dx = player.position.x - b.position.x
        let dy = player.position.y - b.position.y
        let len = hypot(dx,dy)
        let v   = CGVector(dx: dx/len * 200, dy: dy/len * 200)

        b.run(.sequence([
            .move(by: v, duration: 2.0),
            .removeFromParent()
        ]))
    }

    // MARK: –––––––––––––––––––– Movement Helpers –––––––––––––––––––––

    private func moveEnemies(delta dt: TimeInterval) {
        for e in enemies {
            guard let speed = e.userData?["speed"] as? CGFloat else { continue }
            let dx  = player.position.x - e.position.x
            let dy  = player.position.y - e.position.y
            let len = max(hypot(dx,dy), 0.1)
            let mv  = CGVector(dx: dx/len * speed * CGFloat(dt),
                               dy: dy/len * speed * CGFloat(dt))
            e.position.x += mv.dx
            e.position.y += mv.dy
        }
    }

    // MARK: –––––––––––––––––––– Collisions & XP –––––––––––––––––––––

    private func checkCollisions() {
        // Bullet–Enemy
        for bIdx in bullets.indices.reversed() {
            let b = bullets[bIdx]
            for eIdx in enemies.indices.reversed() {
                let e = enemies[eIdx]
                if b.frame.intersects(e.frame) {
                    let dmg = b.userData?["damage"] as? Int ?? 1
                    if var hp = e.userData?["hp"] as? Int {
                        hp -= dmg
                        if hp <= 0 {
                            let xpVal = e.userData?["xp"] as? Int ?? 1
                            xp += xpVal
                            kills += 1
                            e.removeFromParent()
                            enemies.remove(at: eIdx)
                        } else {
                            e.userData?["hp"] = hp
                        }
                    }
                    b.removeFromParent()
                    bullets.remove(at: bIdx)
                    break
                }
            }
        }

        // Enemy–Player
        for (i, e) in enemies.enumerated().reversed() {
            if e.frame.intersects(player.frame) {
                // TODO: handle player HP loss / game over
                e.removeFromParent()
                enemies.remove(at: i)
            }
        }
    }

    // MARK: –––––––––––––––––––– Level‐Up & Upgrades –––––––––––––––––––––

    private func checkLevelUp() {
        guard xp > 0, xp % GameConstants.Upgrade.xpPerLevel == 0 else { return }
        randomUpgrade(reason: "Level Up")
    }

    private func randomUpgrade(reason: String) {
        let options = ["Speed", "Damage", "FireRate", "HP", "Range"]
        if let choice = options.randomElement() {
            applyUpgrade(choice)
            
            // Show a floating label to announce the upgrade
            let lbl = SKLabelNode(text: "\(reason): \(choice)!")
            lbl.fontName = "Helvetica-Bold"
            lbl.fontSize = 22
            lbl.fontColor = .cyan
            lbl.position = CGPoint(x: 0, y: 80) // Position relative to screen center
            lbl.zPosition = 1000
            cameraNode.addChild(lbl) // Add to camera
            
            lbl.run(.sequence([
                .group([
                    .move(by: .init(dx:0, dy:60), duration:1.5),
                    .fadeOut(withDuration: 1.5)
                ]),
                .removeFromParent()
            ]))
        }
    }
    
    private func applyUpgrade(_ choice: String) {
        switch choice {
        case "Speed":
            stats.speed *= 1.10
        case "Damage":
            stats.damage += 1
        case "FireRate":
            stats.fireRate = max(0.1, stats.fireRate * 0.9)
        case "HP":
            stats.hp += 1
        case "Range":
            stats.range *= 1.1
        default:
            print("Error: Unknown upgrade choice '\(choice)'")
        }
    }
}

// MARK: –––––––––––––––––––– CGPoint Helper –––––––––––––––––––––

extension CGPoint {
    func distance(to p: CGPoint) -> CGFloat {
        return hypot(x-p.x, y-p.y)
    }
}
