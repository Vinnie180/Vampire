import SpriteKit
import GameplayKit

// MARK: –––––––––––––––––––– Constants & EnemyTypes –––––––––––––––––––––

struct GameConstants {
    // Map constants
    struct Map {
        static let size          = CGSize(width: 3000, height: 3000)
        static let backgroundColor = UIColor.black
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
        // MODIFIED: Added a speed constant for enemy bullets
        struct Bullet {
            static let speed: CGFloat = 400
        }
    }
    struct Spawn {
        static let rate: TimeInterval             = 0.8  // spawn every 0.8s
        static let indicatorDuration: TimeInterval = 1.0
    }
    struct Upgrade {
        static let xpPerLevel = 10
    }
}

enum BulletOwner {
    case player
    case enemy
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
    
    private var world: SKNode!
    private var cameraNode: SKCameraNode!

    private var player: SKSpriteNode!
    private var joystickBase: SKShapeNode!
    private var joystickKnob: SKShapeNode!
    
    // NEW: UI Labels for HP and Score
    private var hpLabel: SKLabelNode!
    private var scoreLabel: SKLabelNode!

    // MARK: –––––––––––––––––––– State –––––––––––––––––––––

    private var lastSpawnTime: TimeInterval = 0
    private var lastFireTime: TimeInterval  = 0
    private var isGameOver = false // NEW: Game over state flag

    private var enemies: [SKSpriteNode] = []
    private var bullets: [SKShapeNode]  = []

    private let stats = PlayerStats()

    private var xp: Int = 0 {
        didSet { checkLevelUp() }
    }

    private var kills: Int = 0 {
        didSet {
            // MODIFIED: Update the score label whenever kills change
            scoreLabel?.text = "Score: \(kills)"

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
        backgroundColor = .black
        anchorPoint     = CGPoint(x:0.5, y:0.5)

        setupWorld()
        setupCamera()
        
        setupMap()
        setupPlayer()
        setupJoystick()
        setupUI() // NEW: Setup the UI elements
    }
    
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        
        // Reposition joystick and UI if screen size changes
        joystickBase?.position = CGPoint(x: -size.width/2 + 80, y: -size.height/2 + 80)
        hpLabel?.position = CGPoint(x: -size.width/2 + 20, y: size.height/2 - 40)
        scoreLabel?.position = CGPoint(x: size.width/2 - 20, y: size.height/2 - 40)
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
        addChild(cameraNode)
    }
    
    private func setupMap() {
        let mapSize = GameConstants.Map.size
        
        let background = SKShapeNode(rectOf: mapSize)
        background.fillColor = GameConstants.Map.backgroundColor
        background.strokeColor = .clear
        background.zPosition = -100
        world.addChild(background)
        
        let edge = SKShapeNode(rectOf: mapSize)
        edge.fillColor = .clear
        edge.strokeColor = GameConstants.Map.edgeColor
        edge.lineWidth = GameConstants.Map.edgeWidth
        edge.zPosition = -99
        world.addChild(edge)
    }

    private func setupPlayer() {
        player = SKSpriteNode(color: GameConstants.Player.color, size: GameConstants.Player.size)
        player.position = .zero
        world.addChild(player)
    }

    private func setupJoystick() {
        joystickBase = SKShapeNode(circleOfRadius: 50)
        joystickBase.lineWidth   = 2
        joystickBase.strokeColor = .white
        joystickBase.position    = CGPoint(x: -size.width/2 + 80, y: -size.height/2 + 80)
        joystickBase.name        = "joystickBase"
        cameraNode.addChild(joystickBase)

        joystickKnob = SKShapeNode(circleOfRadius: 25)
        joystickKnob.fillColor = .white
        joystickKnob.name      = "joystickKnob"
        joystickKnob.position  = .zero
        joystickBase.addChild(joystickKnob)
    }

    // NEW: Function to set up UI labels
    private func setupUI() {
        // HP Label
        hpLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        hpLabel.fontSize = 20
        hpLabel.fontColor = .white
        hpLabel.horizontalAlignmentMode = .left
        hpLabel.position = CGPoint(x: -size.width/2 + 20, y: size.height/2 - 40)
        hpLabel.text = "HP: \(stats.hp)"
        hpLabel.zPosition = 100 // Ensure UI is on top
        cameraNode.addChild(hpLabel)

        // Score Label
        scoreLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        scoreLabel.fontSize = 20
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.position = CGPoint(x: size.width/2 - 20, y: size.height/2 - 40)
        scoreLabel.text = "Score: 0"
        scoreLabel.zPosition = 100
        cameraNode.addChild(scoreLabel)
    }

    // MARK: –––––––––––––––––––– Touch Handling –––––––––––––––––––––

    private var knobActive = false

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // NEW: If game is over, a tap restarts the scene
        if isGameOver {
            if let view = self.view {
                let newScene = GameScene(size: self.size)
                newScene.scaleMode = self.scaleMode
                let transition = SKTransition.fade(withDuration: 0.5)
                view.presentScene(newScene, transition: transition)
            }
            return
        }

        guard let t = touches.first else { return }
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
        // NEW: Stop all game logic if the game is over
        if isGameOver { return }

        let dt = currentTime - (lastUpdateTime ?? currentTime)
        lastUpdateTime = currentTime

        handlePlayerMovement(delta: dt)
        handleSpawning(time: currentTime)
        handleAutoShoot(time: currentTime)
        moveEnemies(delta: dt)
        checkCollisions()
    }
    
    override func didFinishUpdate() {
        // Center the camera on the player (unless game is over)
        if !isGameOver {
            cameraNode.position = player.position
            clampCameraToMap()
        }
    }

    // MARK: –––––––––––––––––––– Player Movement & Camera –––––––––––––––––––––

    private func handlePlayerMovement(delta dt: TimeInterval) {
        let dx = joystickKnob.position.x / 50
        let dy = joystickKnob.position.y / 50
        let velocity = CGVector(dx: dx * stats.speed * CGFloat(dt),
                                dy: dy * stats.speed * CGFloat(dt))
        
        player.position.x += velocity.dx
        player.position.y += velocity.dy

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
        
        cameraNode.constraints = [xConstraint, yConstraint]
    }

    // MARK: –––––––––––––––––––– Spawning & Indicator –––––––––––––––––––––

    private func handleSpawning(time currentTime: TimeInterval) {
        if currentTime - lastSpawnTime < GameConstants.Spawn.rate { return }
        lastSpawnTime = currentTime

        let cameraPos = cameraNode.position
        let w = size.width/2 + 50
        let h = size.height/2 + 50
        
        let spawnPoints = [
            CGPoint(x: .random(in: cameraPos.x-w...cameraPos.x+w), y: cameraPos.y-h),
            CGPoint(x: .random(in: cameraPos.x-w...cameraPos.x+w), y: cameraPos.y+h),
            CGPoint(x: cameraPos.x-w, y: .random(in: cameraPos.y-h...cameraPos.y+h)),
            CGPoint(x: cameraPos.x+w, y: .random(in: cameraPos.y-h...cameraPos.y+h))
        ]
        let pos = spawnPoints.randomElement()!

        let dot = SKShapeNode(circleOfRadius: 8)
        dot.fillColor = .red; dot.strokeColor = .clear
        dot.position = pos
        world.addChild(dot)

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
        enemy.userData = ["hp": t.baseHP, "xp": t.xpValue, "canShoot": t.canShoot, "speed": t.speed]
        enemy.position = pos
        world.addChild(enemy)
        enemies.append(enemy)

        if t.canShoot {
            let shootAction = SKAction.run { [weak self] in
                self?.enemyShoot(from: enemy)
            }
            let seq = SKAction.sequence([
                .wait(forDuration: 2.0, withRange: 1.0), // Add randomness
                .repeatForever(.sequence([shootAction, .wait(forDuration: 2.5, withRange: 1.0)]))
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
        b.userData = ["damage": damage, "owner": BulletOwner.player]
        world.addChild(b); bullets.append(b)

        let dx = point.x - b.position.x
        let dy = point.y - b.position.y
        let len = hypot(dx,dy)
        let ux  = dx/len, uy = dy/len

        let travel   = stats.range
        let moveBy   = CGVector(dx: ux * travel, dy: uy * travel)
        let duration = TimeInterval(travel / GameConstants.Bullet.speed)

        b.run(.sequence([
            .move(by: moveBy, duration: duration),
            .run { [weak self] in self?.bullets.removeAll { $0 === b } }, // Fix potential memory leak
            .removeFromParent()
        ]))
    }

    // MODIFIED: Enemy bullets are now faster and use a constant for speed
    private func enemyShoot(from enemy: SKSpriteNode) {
        guard let canShoot = enemy.userData?["canShoot"] as? Bool, canShoot else { return }
        
        let b = SKShapeNode(circleOfRadius: GameConstants.Bullet.radius)
        b.fillColor = .magenta
        b.position = enemy.position
        b.userData = ["damage": 1, "owner": BulletOwner.enemy]
        world.addChild(b); bullets.append(b)

        let dx = player.position.x - b.position.x
        let dy = player.position.y - b.position.y
        let len = hypot(dx,dy)
        guard len > 0 else { return } // Avoid division by zero
        let ux  = dx/len
        let uy = dy/len

        // Travel a long fixed distance to ensure it crosses the screen
        let travelDistance: CGFloat = 2000
        let moveBy = CGVector(dx: ux * travelDistance, dy: uy * travelDistance)
        
        // Calculate duration based on the new, faster speed
        let duration = TimeInterval(travelDistance / GameConstants.Enemy.Bullet.speed)

        b.run(.sequence([
            .move(by: moveBy, duration: duration),
            .run { [weak self] in self?.bullets.removeAll { $0 === b } }, // Fix potential memory leak
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

    // MARK: –––––––––––––––––––– Collisions & Death –––––––––––––––––––––

    // MODIFIED: Collision checks now update HP label and check for player death
    private func checkCollisions() {
        var bulletsToRemove: [SKShapeNode] = []

        for bullet in bullets {
            guard let owner = bullet.userData?["owner"] as? BulletOwner else { continue }
            
            switch owner {
            case .player:
                for (enemyIndex, enemy) in enemies.enumerated().reversed() {
                    if bullet.frame.intersects(enemy.frame) {
                        let dmg = bullet.userData?["damage"] as? Int ?? 1
                        if var hp = enemy.userData?["hp"] as? Int {
                            hp -= dmg
                            if hp <= 0 {
                                let xpVal = enemy.userData?["xp"] as? Int ?? 1
                                xp += xpVal
                                kills += 1
                                enemy.removeFromParent()
                                enemies.remove(at: enemyIndex)
                            } else {
                                enemy.userData?["hp"] = hp
                            }
                        }
                        bulletsToRemove.append(bullet)
                        break
                    }
                }
                
            case .enemy:
                if bullet.frame.intersects(player.frame) {
                    stats.hp -= bullet.userData?["damage"] as? Int ?? 1
                    hpLabel.text = "HP: \(stats.hp)" // Update UI
                    checkPlayerDeath() // Check if the player has died
                    bulletsToRemove.append(bullet)
                }
            }
        }
        
        if !bulletsToRemove.isEmpty {
            for bullet in bulletsToRemove {
                bullet.removeFromParent()
            }
            bullets.removeAll { bulletsToRemove.contains($0) }
        }
        
        for (i, e) in enemies.enumerated().reversed() {
            if e.frame.intersects(player.frame) {
                stats.hp -= 1
                hpLabel.text = "HP: \(stats.hp)" // Update UI
                checkPlayerDeath() // Check if the player has died
                e.removeFromParent()
                enemies.remove(at: i)
            }
        }
    }
    
    // NEW: Function to check if player HP is <= 0 and trigger game over
    private func checkPlayerDeath() {
        if stats.hp <= 0 && !isGameOver {
            handleGameOver()
        }
    }
    
    // NEW: Function to handle the game over sequence
    private func handleGameOver() {
        isGameOver = true
        world.isPaused = true // Freezes all enemies, bullets, and spawners
        
        // Darken the screen
        let overlay = SKShapeNode(rectOf: size)
        overlay.fillColor = .black
        overlay.strokeColor = .clear
        overlay.alpha = 0.7
        overlay.zPosition = 1999
        cameraNode.addChild(overlay)

        // "YOU DIED" text
        let deathLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        deathLabel.text = "YOU DIED"
        deathLabel.fontSize = 60
        deathLabel.fontColor = .red
        deathLabel.position = CGPoint(x: 0, y: 50)
        deathLabel.zPosition = 2000
        cameraNode.addChild(deathLabel)

        // Final score text
        let finalScoreLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        finalScoreLabel.text = "Final Score: \(kills)"
        finalScoreLabel.fontSize = 30
        finalScoreLabel.fontColor = .white
        finalScoreLabel.position = CGPoint(x: 0, y: -10)
        finalScoreLabel.zPosition = 2000
        cameraNode.addChild(finalScoreLabel)
        
        // Restart instruction with a pulsing animation
        let restartLabel = SKLabelNode(fontNamed: "Helvetica")
        restartLabel.text = "Tap to Restart"
        restartLabel.fontSize = 22
        restartLabel.fontColor = .white
        restartLabel.position = CGPoint(x: 0, y: -80)
        restartLabel.zPosition = 2000
        restartLabel.alpha = 0
        cameraNode.addChild(restartLabel)
        
        let fadeIn = SKAction.fadeIn(withDuration: 0.7)
        let fadeOut = SKAction.fadeOut(withDuration: 0.7)
        let pulse = SKAction.sequence([fadeIn, fadeOut])
        let waitAndPulse = SKAction.sequence([.wait(forDuration: 1.0), .repeatForever(pulse)])
        restartLabel.run(waitAndPulse)
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
            
            let lbl = SKLabelNode(text: "\(reason): \(choice)!")
            lbl.fontName = "Helvetica-Bold"
            lbl.fontSize = 22
            lbl.fontColor = .cyan
            lbl.position = CGPoint(x: 0, y: 80)
            lbl.zPosition = 1000
            cameraNode.addChild(lbl)
            
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
            hpLabel.text = "HP: \(stats.hp)" // Update UI when HP is upgraded
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
