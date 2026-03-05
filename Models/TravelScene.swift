import SpriteKit

final class TravelScene: SKScene {
    private let character = SKSpriteNode()
    private var trackY: CGFloat { size.height * 0.43 }

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        if character.parent == nil {
            character.anchorPoint = CGPoint(x: 0.5, y: 0.1)
            addChild(character)
        }
        character.position = CGPoint(x: size.width * 0.08, y: trackY)
    }

    func configureCharacter(assetName: String) {
        character.texture = SKTexture(imageNamed: assetName)
        character.size = CGSize(width: 84, height: 84)
    }

    func setProgress(_ value: CGFloat, animated: Bool, duration: TimeInterval, reduceMotion: Bool) {
        let clamped = min(1, max(0, value))
        let targetX = size.width * 0.08 + (size.width * 0.84 * clamped)
        let target = CGPoint(x: targetX, y: trackY)

        character.removeAllActions()
        if animated && duration > 0.01 {
            let move = SKAction.move(to: target, duration: duration)
            move.timingMode = .easeInEaseOut

            if reduceMotion {
                character.run(move)
            } else {
                let bobUp = SKAction.moveBy(x: 0, y: 8, duration: 0.25)
                bobUp.timingMode = .easeInEaseOut
                let bobDown = bobUp.reversed()
                let bob = SKAction.repeatForever(.sequence([bobUp, bobDown]))

                let rotA = SKAction.rotate(toAngle: .pi / 24, duration: 0.25)
                let rotB = SKAction.rotate(toAngle: -.pi / 24, duration: 0.25)
                let rot = SKAction.repeatForever(.sequence([rotA, rotB]))

                character.run(.group([move, bob, rot])) {
                    self.character.removeAllActions()
                    self.character.zRotation = 0
                    self.character.position = target
                }
            }
        } else {
            character.position = target
        }
    }
}
